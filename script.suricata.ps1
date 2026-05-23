# =============================================================
# Suricata NIDS - Automated Network Monitor
# - Installs Suricata + Emerging Threats rules (first run)
# - Uses dumpcap (Wireshark) for reliable Wi-Fi capture
# - Survives reboots via Scheduled Tasks
# - Every run: restarts capture, collects logs, zips results
# =============================================================

$ErrorActionPreference = "Stop"

# ── PATHS ─────────────────────────────────────────────────────
$suricataDir      = "C:\Suricata"
$suricataExe      = "$suricataDir\suricata.exe"
$rulesDir         = "$suricataDir\rules"
$logDir           = "$suricataDir\log"
$pcapDir          = "$suricataDir\pcap"
$yamlConf         = "$suricataDir\suricata.yaml"
$captureScript    = "$suricataDir\capture_loop.ps1"
$tmpDir           = "C:\Windows\Temp"
$msiPath          = "$tmpDir\suricata_setup.msi"
$captureTaskName  = "DFIR-Capture"
$suricataTaskName = "DFIR-Suricata"
$dumpcapExe       = "C:\Program Files\Wireshark\dumpcap.exe"

# ── HELPERS ───────────────────────────────────────────────────
function Write-Step { param($msg) Write-Host "[+] $msg" }
function Write-Info  { param($msg) Write-Host "[~] $msg" }
function Write-Fail  { param($msg) Write-Host "[!] $msg" }

function Get-WifiGuid {
    $lines = & $dumpcapExe -D 2>$null
    foreach ($line in $lines) {
        if ($line -match '\d+\.\s+(\S+)\s+\(Wi-Fi\)') { return $Matches[1] }
    }
    # fallback: first non-VMware/loopback/virtual interface
    foreach ($line in $lines) {
        if ($line -match '\d+\.\s+(\S+)\s+\((?!VMware|Loopback|vEthernet|Radmin|WSL|Local Area Connection\*)') {
            return $Matches[1]
        }
    }
    throw "Could not find Wi-Fi interface in dumpcap output"
}

function Find-SuricataExe {
    if (Test-Path $suricataExe) { return $suricataExe }
    $found = Get-ChildItem "C:\Program Files" -Recurse -Filter "suricata.exe" -ErrorAction SilentlyContinue |
             Select-Object -First 1
    if ($found) { return $found.FullName }
    throw "suricata.exe not found"
}

function Register-Task {
    param($name, $exe, $taskArgs, $description)
    $action    = New-ScheduledTaskAction -Execute $exe -Argument $taskArgs
    $trigger   = New-ScheduledTaskTrigger -AtStartup
    $settings  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit 0 -RestartCount 5 `
                     -RestartInterval (New-TimeSpan -Minutes 1)
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger `
        -Settings $settings -Principal $principal -Description $description -Force | Out-Null
    # Hide the task
    $xml = Export-ScheduledTask -TaskName $name
    if ($xml -notmatch '<Hidden>true</Hidden>') {
        $xml = $xml -replace '<Hidden>false</Hidden>', '<Hidden>true</Hidden>'
        if ($xml -notmatch '<Hidden>true</Hidden>') {
            $xml = $xml -replace '<Settings>', '<Settings><Hidden>true</Hidden>'
        }
        Register-ScheduledTask -TaskName $name -Xml $xml -Force | Out-Null
    }
}

function Stop-AllTasks {
    Stop-ScheduledTask $captureTaskName  -ErrorAction SilentlyContinue
    Stop-ScheduledTask $suricataTaskName -ErrorAction SilentlyContinue
    Stop-Process -Name suricata  -Force -ErrorAction SilentlyContinue
    Stop-Process -Name dumpcap   -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
}

function Write-CaptureScript {
    param($guid)
    @"
while (`$true) {
    `$ts      = Get-Date -Format 'yyyyMMdd_HHmmss'
    `$outFile = "$pcapDir\capture_`$ts.pcap"
    & "$dumpcapExe" -i "$guid" -a duration:30 -s 0 -w `$outFile -q 2>`$null
    Start-Sleep -Seconds 1
}
"@ | Set-Content -Path $captureScript -Encoding ASCII
}

function Write-SuricataYaml {
    param($homeNet, $ruleFilesYaml)
    @"
%YAML 1.1
---
vars:
  address-groups:
    HOME_NET: "[$homeNet]"
    EXTERNAL_NET: "!`$HOME_NET"
    HTTP_SERVERS:   "`$HOME_NET"
    SMTP_SERVERS:   "`$HOME_NET"
    SQL_SERVERS:    "`$HOME_NET"
    DNS_SERVERS:    "`$HOME_NET"
    TELNET_SERVERS: "`$HOME_NET"
    AIM_SERVERS:    "`$EXTERNAL_NET"
    DNP3_SERVER:    "`$HOME_NET"
    DNP3_CLIENT:    "`$HOME_NET"
    MODBUS_CLIENT:  "`$HOME_NET"
    MODBUS_SERVER:  "`$HOME_NET"
    ENIP_CLIENT:    "`$HOME_NET"
    ENIP_SERVER:    "`$HOME_NET"
  port-groups:
    HTTP_PORTS:      "[80,8080,8000,8008,8888,8443,443]"
    SHELLCODE_PORTS: "!`$HTTP_PORTS"
    ORACLE_PORTS:    1521
    SSH_PORTS:       22
    DNP3_PORTS:      20000
    MODBUS_PORTS:    502
    FILE_DATA_PORTS: "[`$HTTP_PORTS,110,143]"
    FTP_PORTS:       21
    GENEVE_PORTS:    6081
    VXLAN_PORTS:     4789
    TEREDO_PORTS:    3544

default-log-dir: $logDir

stats:
  enabled: yes
  interval: 8

outputs:
  - fast:
      enabled: yes
      filename: fast.log
      append: yes
  - eve-log:
      enabled: yes
      filetype: regular
      filename: eve.json
      types:
        - alert:
            payload: yes
            payload-buffer-size: 4kb
            payload-printable: yes
            packet: yes
            metadata: yes
            http-body: yes
            http-body-printable: yes
            tagged-packets: yes
        - http:
            extended: yes
        - dns:
            query: yes
            answer: yes
        - tls:
            extended: yes
        - files:
            force-magic: no
        - smtp:
            extended: yes
        - ssh
        - flow
  - http-log:
      enabled: yes
      filename: http.log
      append: yes
  - stats:
      enabled: yes
      filename: stats.log
      append: yes
      totals: yes

logging:
  default-log-level: notice
  outputs:
    - console:
        enabled: no
    - file:
        enabled: yes
        level: info
        filename: $logDir\suricata.log

pcap-file:
  checksum-checks: no
  delete-when-done: true
  continuous: true
  delay: 5
  poll-interval: 3

app-layer:
  protocols:
    tls:
      enabled: yes
      detection-ports:
        dp: 443
    dcerpc:
      enabled: yes
    modbus:
      enabled: yes
      detection-ports:
        dp: 502
    ftp:
      enabled: yes
    ssh:
      enabled: yes
    smtp:
      enabled: yes
      mime:
        decode-mime: yes
        decode-base64: yes
        decode-quoted-printable: yes
        header-value-depth: 2000
        extract-urls: yes
    imap:
      enabled: detection-only
    dns:
      tcp:
        enabled: yes
        detection-ports:
          dp: 53
      udp:
        enabled: yes
        detection-ports:
          dp: 53
    http:
      enabled: yes
      libhtp:
        default-config:
          personality: IDS
          request-body-limit: 100kb
          response-body-limit: 100kb
          request-body-minimal-inspect-size: 32kb
          request-body-inspect-window: 4kb
          response-body-minimal-inspect-size: 40kb
          response-body-inspect-window: 16kb
          double-decode-path: no
          double-decode-query: no

asn1-max-frames: 256
host-mode: auto

pcre:
  match-limit: 3500
  match-limit-recursion: 1500

flow:
  memcap: 128mb
  hash-size: 65536
  prealloc: 10000
  emergency-recovery: 30

flow-timeouts:
  default:
    new: 30
    established: 300
    closed: 0
    bypassed: 100
    emergency-new: 10
    emergency-established: 100
    emergency-closed: 0
    emergency-bypassed: 50
  tcp:
    new: 60
    established: 600
    closed: 60
    bypassed: 100
    emergency-new: 5
    emergency-established: 100
    emergency-closed: 10
    emergency-bypassed: 50
  udp:
    new: 30
    established: 300
    bypassed: 100
    emergency-new: 10
    emergency-established: 100
    emergency-bypassed: 50
  icmp:
    new: 30
    established: 300
    bypassed: 100
    emergency-new: 10
    emergency-established: 100
    emergency-bypassed: 50

stream:
  memcap: 64mb
  checksum-validation: no
  inline: no
  reassembly:
    memcap: 256mb
    depth: 1mb
    toserver-chunk-size: 2560
    toclient-chunk-size: 2560
    randomize-chunk-size: yes

host:
  hash-size: 4096
  prealloc: 1000
  memcap: 32mb

defrag:
  memcap: 32mb
  hash-size: 65536
  trackers: 65535
  max-frags: 65535
  prealloc: yes
  timeout: 60

detect:
  profile: medium
  custom-values:
    toclient-groups: 3
    toserver-groups: 25
  sgh-mpm-context: auto
  inspection-recursion-limit: 3000
  prefilter:
    default: mpm

mpm-algo: auto
spm-algo: auto

threading:
  set-cpu-affinity: no
  detect-thread-ratio: 1.0

luajit:
  states: 128

exception-policy: auto

rule-files:
$ruleFilesYaml

classification-file: $rulesDir\classification.config
reference-config-file: $rulesDir\reference.config
threshold-file: $rulesDir\threshold.conf
"@ | Set-Content -Path $yamlConf -Encoding ASCII
}

function Write-ThresholdConf {
    @"
# Suppress high-volume low-signal rules
suppress gen_id 1, sig_id 2008983
suppress gen_id 1, sig_id 2012648
suppress gen_id 1, sig_id 2013028
suppress gen_id 1, sig_id 2014819
suppress gen_id 1, sig_id 2027758
# Rate-limit noisy scan rules
threshold gen_id 1, sig_id 2009358, type threshold, track by_src, count 5, seconds 60
threshold gen_id 1, sig_id 2001219, type threshold, track by_src, count 5, seconds 60
threshold gen_id 1, sig_id 2023883, type threshold, track by_src, count 3, seconds 60
# Suppress TCP stream reassembly noise from offline pcap mode
suppress gen_id 1, sig_id 2210029
suppress gen_id 1, sig_id 2210030
suppress gen_id 1, sig_id 2210031
suppress gen_id 1, sig_id 2210032
# Suppress Windows NCSI connectivity check
suppress gen_id 1, sig_id 2031071
# Suppress Discord DNS info rules (not threats)
suppress gen_id 1, sig_id 2060503
suppress gen_id 1, sig_id 2035465
# Suppress TCP stream noise from offline pcap mode
suppress gen_id 1, sig_id 2210054
suppress gen_id 1, sig_id 2210023
suppress gen_id 1, sig_id 2210027
"@ | Set-Content -Path "$rulesDir\threshold.conf" -Encoding ASCII
}

function Get-RuleFilesYaml {
    # Exclude rules that require keywords not supported in offline pcap mode
    $excluded = @("emerging-hunting.rules", "modbus-events.rules")
    return (Get-ChildItem -Path $rulesDir -Filter "*.rules" -ErrorAction SilentlyContinue |
        Where-Object { $excluded -notcontains $_.Name } |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { "  - $_" }) -join "`n"
}

function Collect-AndZip {
    Write-Step "Collecting logs and zipping results"
    $resultsDir = "C:\results"
    Remove-Item $resultsDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $resultsDir | Out-Null
    Get-ChildItem -Path $logDir -File -ErrorAction SilentlyContinue |
        Copy-Item -Destination $resultsDir -Force

    $zip = "C:\results.zip"
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path "$resultsDir\*" -DestinationPath $zip -Force
    $alertCount = (Get-Content "$logDir\fast.log" -ErrorAction SilentlyContinue |
                   Measure-Object -Line).Lines
    Write-Step "Done -- $alertCount alerts -- results at $zip"
}

# ==============================================================
# MAIN
# ==============================================================

# ── Ensure directories exist ──────────────────────────────────
foreach ($d in @($suricataDir, $rulesDir, $logDir, $pcapDir)) {
    New-Item -ItemType Directory -Path $d -Force | Out-Null
}

# ── Step 1: Suricata ──────────────────────────────────────────
if (-not (Test-Path $suricataExe)) {
    Write-Step "Downloading Suricata 8.0.4"
    Invoke-WebRequest `
        -Uri "https://www.openinfosecfoundation.org/download/windows/Suricata-8.0.4-1-64bit.msi" `
        -OutFile $msiPath -UseBasicParsing
    Write-Step "Installing Suricata (silent)"
    Start-Process "msiexec.exe" `
        -ArgumentList "/i `"$msiPath`" /quiet /norestart INSTALLDIR=`"$suricataDir`"" `
        -Wait -WindowStyle Hidden
    Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
}
$suricataExe = Find-SuricataExe
Write-Info "Suricata: $suricataExe"

# ── Step 2: Wireshark / dumpcap ───────────────────────────────
# dumpcap ships with Wireshark and needs npcap as its capture driver.
# If Wireshark is missing we install it silently via winget (built into
# Windows 11 and Windows 10 2004+) which handles npcap automatically.
# Fallback: direct MSI download of a pinned Wireshark version.
if (-not (Test-Path $dumpcapExe)) {
    Write-Step "Wireshark not found -- installing"

    # Try winget first (silent, no UAC prompts beyond initial elevation)
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Info "Installing via winget"
        & winget install --id WiresharkFoundation.Wireshark `
            --silent --accept-package-agreements --accept-source-agreements `
            --override "/S" 2>$null
    }

    # If still not found, fall back to direct download of pinned version
    if (-not (Test-Path $dumpcapExe)) {
        Write-Info "winget failed or unavailable -- downloading Wireshark 4.4.6 directly"
        $wsInstaller = "$tmpDir\wireshark_setup.exe"
        Invoke-WebRequest `
            -Uri "https://2.na.dl.wireshark.org/win64/Wireshark-4.4.6-x64.exe" `
            -OutFile $wsInstaller -UseBasicParsing
        # /S = truly silent install, includes npcap driver
        Start-Process $wsInstaller -ArgumentList "/S" -Wait -Verb RunAs
        Remove-Item $wsInstaller -Force -ErrorAction SilentlyContinue
    }

    if (-not (Test-Path $dumpcapExe)) {
        throw "dumpcap not found after install -- ensure Wireshark installed correctly"
    }
    Write-Step "Wireshark installed"
}
Write-Info "dumpcap: $dumpcapExe"

# ── Step 3: Wi-Fi interface GUID ──────────────────────────────
$wifiGuid = Get-WifiGuid
Write-Info "Wi-Fi interface: $wifiGuid"

# ── Step 4: Emerging Threats rules ────────────────────────────
if (-not (Test-Path "$rulesDir\emerging-sql.rules")) {
    Write-Step "Downloading Emerging Threats ruleset"
    $etZip = "$tmpDir\emerging_threats.tar.gz"
    Invoke-WebRequest `
        -Uri "https://rules.emergingthreats.net/open/suricata-5.0/emerging.rules.tar.gz" `
        -OutFile $etZip -UseBasicParsing
    tar -xzf $etZip -C $rulesDir --strip-components=1
    Remove-Item $etZip -Force -ErrorAction SilentlyContinue
    Write-Step "Rules installed"
} else {
    Write-Info "ET rules already present"
}
foreach ($f in @("classification.config", "reference.config")) {
    if (-not (Test-Path "$rulesDir\$f")) {
        New-Item -ItemType File -Path "$rulesDir\$f" -Force | Out-Null
    }
}

# ── Step 5: Write config files ────────────────────────────────
$ip       = (Get-NetIPAddress -InterfaceAlias (
                 (Get-NetAdapter | Where-Object {
                     $_.Status -eq "Up" -and
                     ($_.Name -like "*Wi-Fi*" -or $_.Name -like "*Wireless*" -or
                      $_.PhysicalMediaType -like "*802.11*")
                 } | Select-Object -First 1).Name `
             ) -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
if (-not $ip) { $ip = "192.168.1.0" }
$homeNet = "$ip/24"

Write-SuricataYaml -homeNet $homeNet -ruleFilesYaml (Get-RuleFilesYaml)
Write-ThresholdConf
Write-CaptureScript -guid $wifiGuid
Write-Step "Config files written (HOME_NET: $homeNet)"

# ── Step 6: Stop everything running ───────────────────────────
Write-Step "Stopping existing tasks"
Stop-AllTasks

# ── Step 7: Register scheduled tasks ─────────────────────────
Register-Task `
    -name $captureTaskName `
    -exe "powershell.exe" `
    -taskArgs "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$captureScript`"" `
    -description "dumpcap Wi-Fi capture - DFIR"

Register-Task `
    -name $suricataTaskName `
    -exe $suricataExe `
    -taskArgs "-c `"$yamlConf`" -r `"$pcapDir`" --pcap-file-continuous --pcap-file-delete -l `"$logDir`"" `
    -description "Suricata NIDS - DFIR"

Write-Step "Tasks registered"

# ── Step 8: Start both tasks ──────────────────────────────────
Start-ScheduledTask $captureTaskName
Write-Step "Capture started (dumpcap -> $pcapDir)"
Start-Sleep -Seconds 5

Start-ScheduledTask $suricataTaskName
Write-Step "Suricata started"
Start-Sleep -Seconds 15

# ── Step 9: Verify ────────────────────────────────────────────
$sProc = Get-Process -Name suricata -ErrorAction SilentlyContinue
$dProc = Get-Process -Name dumpcap  -ErrorAction SilentlyContinue
if ($sProc) { Write-Step "Suricata running (PID $($sProc.Id))" }
else        { Write-Fail "Suricata not detected -- check $logDir\suricata.log" }
if ($dProc) { Write-Step "dumpcap running (PID $($dProc.Id))" }
else        { Write-Fail "dumpcap not detected -- check task scheduler" }

# ── Step 10: Wait for first pcap and collect ─────────────────
Write-Step "Waiting 35s for first capture cycle..."
Start-Sleep -Seconds 35

$alertCount = (Get-Content "$logDir\fast.log" -ErrorAction SilentlyContinue |
               Measure-Object -Line).Lines
Write-Step "Alerts so far: $alertCount"
if ($alertCount -gt 0) {
    Write-Host ""
    Write-Host "Top alert types:"
    Get-Content "$logDir\fast.log" -ErrorAction SilentlyContinue |
        Select-String '\[\*\*\] (.+) \[\*\*\]' |
        ForEach-Object { $_.Matches[0].Groups[1].Value } |
        Group-Object | Sort-Object Count -Descending |
        Select-Object -First 10 |
        ForEach-Object { Write-Host "  $($_.Count)x  $($_.Name)" }
    Write-Host ""
}

Collect-AndZip