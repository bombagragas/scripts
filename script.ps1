Write-Host "=== DFIR Automation Script Started ==="

# -----------------------------
# 1️⃣ CHECK / INSTALL GIT
# -----------------------------
Write-Host "[+] Checking for Git..."
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    Write-Host "[+] Git not found. Installing Git..."
    $gitInstaller = "C:\git-installer.exe"
    Invoke-WebRequest `
        -Uri "https://github.com/git-for-windows/git/releases/latest/download/Git-2.42.0-64-bit.exe" `
        -OutFile $gitInstaller
    Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT", "/NORESTART" -Wait
    Remove-Item $gitInstaller

    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH", "User")
} else {
    Write-Host "[+] Git is already installed."
}

# -----------------------------
# 2️⃣ DOWNLOAD TOOLS
# -----------------------------
Write-Host "[+] Downloading LOKI..."
Invoke-WebRequest `
    -Uri "https://github.com/Neo23x0/Loki/releases/latest/download/loki_0.51.0.zip" `
    -OutFile "C:\loki_0.51.0.zip"

Write-Host "[+] Downloading Hayabusa..."
Invoke-WebRequest `
    -Uri "https://github.com/Yamato-Security/hayabusa/releases/download/v3.8.0/hayabusa-3.8.0-win-x86.zip" `
    -OutFile "C:\hayabusa-3.8.0-win-x86.zip"

# -----------------------------
# 3️⃣ CLONE HOARDER REPO
# -----------------------------
$hoarderTemp = "C:\hoarder_temp"
$hoarderDir  = "$hoarderTemp\releases"

if (Test-Path $hoarderTemp) {
    Write-Host "[+] Removing old hoarder_temp..."
    Remove-Item -Path $hoarderTemp -Recurse -Force
}

Write-Host "[+] Cloning Hoarder repository..."
git clone --depth 1 https://github.com/DFIRKuiper/Hoarder.git $hoarderTemp

if (-not (Test-Path $hoarderDir)) {
    Write-Host "[!] ERROR: Expected releases folder not found at $hoarderDir"
    Get-ChildItem $hoarderTemp | ForEach-Object { Write-Host "    $_" }
    exit 1
}

# -----------------------------
# 4️⃣ EXTRACT TOOLS
# -----------------------------
Write-Host "[+] Extracting LOKI..."
Expand-Archive "C:\loki_0.51.0.zip" "C:\loki" -Force

Write-Host "[+] Extracting Hayabusa..."
Expand-Archive "C:\hayabusa-3.8.0-win-x86.zip" "C:\hayabusa" -Force

# -----------------------------
# 5️⃣ PREPARE RESULTS FOLDER
# -----------------------------
Write-Host "[+] Preparing results folder..."
$resultsDir = "C:\results"

if (Test-Path $resultsDir) {
    Remove-Item -Path $resultsDir -Recurse -Force
}
New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null

# -----------------------------
# 6️⃣ RUN LOKI
# -----------------------------
Write-Host "[+] Running LOKI..."
Set-Location "C:\loki\loki"
.\loki.exe

# Loki writes .log files into its own folder — grab only those
Write-Host "[+] Collecting LOKI logs..."
$lokiLogs = Get-ChildItem -Path "C:\loki\loki" -Filter "*.log"
if ($lokiLogs) {
    foreach ($log in $lokiLogs) {
        Copy-Item -Path $log.FullName -Destination $resultsDir -Force
        Write-Host "[+] Copied: $($log.Name)"
    }
} else {
    Write-Host "[!] WARNING: No LOKI log files found."
}

# -----------------------------
# 7️⃣ RUN HOARDER
# -----------------------------
Write-Host "[+] Running Hoarder (-vv)..."
Set-Location $hoarderDir

# Snapshot ZIPs before running so we only grab the new one
$zipsBefore = Get-ChildItem -Path $hoarderDir -Filter "*.zip" |
              Select-Object -ExpandProperty FullName

.\hoarder.exe -vv

# Grab only the ZIP Hoarder just created
Write-Host "[+] Collecting Hoarder ZIP..."
$newZip = Get-ChildItem -Path $hoarderDir -Filter "*.zip" |
          Where-Object { $zipsBefore -notcontains $_.FullName } |
          Sort-Object LastWriteTime -Descending |
          Select-Object -First 1

if ($newZip) {
    Copy-Item -Path $newZip.FullName -Destination $resultsDir -Force
    Write-Host "[+] Copied ZIP: $($newZip.Name)"
} else {
    Write-Host "[!] WARNING: No new ZIP found in $hoarderDir"
    Write-Host "[i] Contents of releases folder:"
    Get-ChildItem $hoarderDir | ForEach-Object { Write-Host "    $($_.FullName)" }
}

# -----------------------------
# 8️⃣ RUN HAYABUSA
# -----------------------------
Write-Host "[+] Running Hayabusa..."
$hayabusaExe = "C:\hayabusa\hayabusa-3.8.0-win-x86.exe"
$logsPath    = "C:\Windows\System32\winevt\Logs"
$rulesPath   = "C:\hayabusa\rules"
$outputJson  = "C:\hayabusa\sec.json"
$outputHTML  = "C:\hayabusa\sec_summary.html"

& $hayabusaExe `
    json-timeline `
    --no-wizard `
    -d $logsPath `
    --sort `
    --profile timesketch-minimal `
    --rules $rulesPath `
    --output $outputJson `
    -T `
    --HTML-report $outputHTML

# Grab only the two output files, not the entire hayabusa folder
Write-Host "[+] Collecting Hayabusa results..."
foreach ($file in @($outputJson, $outputHTML)) {
    if (Test-Path $file) {
        Copy-Item -Path $file -Destination $resultsDir -Force
        Write-Host "[+] Copied: $(Split-Path $file -Leaf)"
    } else {
        Write-Host "[!] WARNING: Expected Hayabusa output not found: $file"
    }
}

# -----------------------------
# 9️⃣ CREATE FINAL ZIP
# -----------------------------
$zipPath = "C:\results.zip"
if (Test-Path $zipPath) { Remove-Item -Path $zipPath -Force }

$resultItems = Get-ChildItem -Path $resultsDir
if ($resultItems) {
    Compress-Archive -Path "$resultsDir\*" -DestinationPath $zipPath -Force
    Write-Host "[+] DONE — Results ready at $zipPath"
    Write-Host "[i] Final contents:"
    $resultItems | ForEach-Object { Write-Host "    $($_.Name)" }
} else {
    Write-Host "[!] Results folder is empty — skipping ZIP creation."
}