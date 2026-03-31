Write-Host "=== DFIR Automation Script Started ==="

# -----------------------------
# 1️⃣ DOWNLOAD TOOLS
# -----------------------------

$lokiZip     = "C:\loki_0.51.0.zip"
$extractPath = "C:\loki"
$lokiExe     = "C:\loki\loki\loki.exe"
$lokiLog     = "C:\loki\loki\loki_scan.log"

if (Test-Path $lokiExe) {
    Write-Host "[~] LOKI already extracted, skipping download and extraction"
} else {
    if (Test-Path $lokiZip) {
        Write-Host "[~] LOKI ZIP already downloaded, skipping download"
    } else {
        Write-Host "[+] Downloading LOKI"
        Invoke-WebRequest `
            -Uri "https://github.com/Neo23x0/Loki/releases/latest/download/loki_0.51.0.zip" `
            -OutFile $lokiZip
    }

    # -----------------------------
    # 2️⃣ EXTRACT & RENAME
    # -----------------------------
    Write-Host "[+] Extracting LOKI"
    Expand-Archive $lokiZip $extractPath -Force
}


# -----------------------------
# 3️⃣ RUN TOOLS
# -----------------------------

# Clear previous log so it always overwrites
if (Test-Path $lokiLog) {
    Clear-Content -Path $lokiLog
    Write-Host "[~] Cleared previous LOKI log"
}

Write-Host "[+] Running LOKI"
Set-Location "C:\loki\loki"
.\loki.exe `
    --logfile $lokiLog `
    --noproc `
    --nofilesystem `
    -p "C:\Users" `
    -p "C:\ProgramData" `
    -p "C:\Windows\Temp" `
    -p "C:\Temp" `
    --csv `
    --dontwait


# -----------------------------
# ✅ Collect and zip results
# -----------------------------
Write-Host "[+] Preparing results folder"

$resultsDir = "C:\results"
Remove-Item -Path $resultsDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $resultsDir | Out-Null

# -----------------------------
# Collect outputs from tools
# -----------------------------
Write-Host "[+] Collecting LOKI logs"
Copy-Item -Path $lokiLog -Destination $resultsDir -ErrorAction SilentlyContinue

# -----------------------------
# Create final ZIP for SFTP
# -----------------------------
$finalZip = "C:\results.zip"
if (Test-Path $finalZip) { Remove-Item -Path $finalZip -Force }
Compress-Archive -Path "$resultsDir\*" -DestinationPath $finalZip -Force

Write-Host "[+] DONE  Results ready at $finalZip"