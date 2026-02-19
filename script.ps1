Write-Host "=== DFIR Automation Script Started ==="

# -----------------------------
# 1️⃣ DOWNLOAD TOOLS
# -----------------------------
Write-Host "[+] Downloading LOKI"
Invoke-WebRequest `
 -Uri "https://github.com/Neo23x0/Loki/releases/latest/download/loki_0.51.0.zip" `
 -OutFile "C:\loki_0.51.0.zip"

Write-Host "[+] Downloading Hoarder repository"
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    Write-Host "[+] Git not found. Installing Git..."
    $gitInstaller = "C:\git-installer.exe"
    Invoke-WebRequest `
        -Uri "https://github.com/git-for-windows/git/releases/latest/download/Git-2.42.0-64-bit.exe" `
        -OutFile $gitInstaller
    Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT", "/NORESTART" -Wait
    Remove-Item $gitInstaller
} else {
    Write-Host "[+] Git is already installed."
}

# -----------------------------
# 3️⃣ CLONE HOARDER REPO
# -----------------------------
Write-Host "[+] Cloning Hoarder repository"
# Shallow clone to save time
git clone --depth 1 https://github.com/DFIRKuiper/Hoarder.git C:\hoarder_temp
$hoarderDir = "C:\hoarder_temp\releases"


Write-Host "[+] Downloading Hayabusa"
Invoke-WebRequest `
 -Uri "https://github.com/Yamato-Security/hayabusa/releases/download/v3.8.0/hayabusa-3.8.0-win-x86.zip" `
 -OutFile "C:\hayabusa-3.8.0-win-x86.zip"


# -----------------------------
# 2️⃣ EXTRACT & RENAME
# -----------------------------
Write-Host "[+] Extracting LOKI"
Expand-Archive "C:\loki_0.51.0.zip" "C:\loki" -Force

Write-Host "[+] Extracting Hayabusa"
Expand-Archive "C:\hayabusa-3.8.0-win-x86.zip" "C:\hayabusa" -Force



# -----------------------------
# 3️⃣ RUN TOOLS
# -----------------------------
Write-Host "[+] Running LOKI"
Set-Location "C:\loki\loki"
.\loki

Write-Host "[+] Running Hoarder (-vv)"
Set-Location $hoarderDir
.\hoarder.exe -vv

Write-Host "[+] Running Hayabusa"

$hayabusaExe = "C:\hayabusa\hayabusa-3.8.0-win-x86.exe"
$logsPath    = "C:\Windows\System32\winevt\Logs"
$rulesPath   = "C:\hayabusa\rules"
$outputCSV   = "C:\hayabusa\sec.csv"
$outputHTML  = "C:\hayabusa\sec_summary.html"

& $hayabusaExe `
  csv-timeline `
  --no-wizard `
  -d $logsPath `
  --sort `
  --profile timesketch-minimal `
  --rules $rulesPath `
  --output $outputCSV `
  -T `
  --HTML-report $outputHTML



# -----------------------------
# -----------------------------
# 4️⃣ COLLECT RESULTS
# -----------------------------
Write-Host "[+] Preparing result folder"

$results = "C:\results"
Remove-Item $results -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $results | Out-Null

Write-Host "[+] Collecting LOKI logs"
Copy-Item "C:\loki\loki\*.log" $results -ErrorAction SilentlyContinue

Write-Host "[+] Collecting Hayabusa results"
Copy-Item "C:\hayabusa\sec.csv" $results -ErrorAction SilentlyContinue
Copy-Item "C:\hayabusa\sec_summary.html" $results -ErrorAction SilentlyContinue

Write-Host "[+] Collecting Hoarder results"
Copy-Item "C:\hoarder_temp\releases\*" "$results\hoarder" -Recurse -ErrorAction SilentlyContinue

Write-Host "[+] Creating ZIP archive"
Compress-Archive -Path "$results\*" -DestinationPath "C:\dfir_results.zip" -Force

Write-Host "[+] DONE — Results ready at C:\dfir_results.zip"

