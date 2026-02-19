Write-Host "=== DFIR Automation Script Started ==="

# -----------------------------
# 1️⃣ DOWNLOAD TOOLS
# -----------------------------
Write-Host "[+] Downloading LOKI"
Invoke-WebRequest `
 -Uri "https://github.com/Neo23x0/Loki/releases/latest/download/loki_0.51.0.zip" `
 -OutFile "C:\loki_0.51.0.zip"


# -----------------------------
# 2️⃣ EXTRACT & RENAME
# -----------------------------
Write-Host "[+] Extracting LOKI"
Expand-Archive "C:\loki_0.51.0.zip" "C:\loki" -Force


# -----------------------------
# 3️⃣ RUN TOOLS
# -----------------------------
Write-Host "[+] Running LOKI"
Set-Location "C:\loki\loki"
.\loki


# -----------------------------
# -----------------------------
# ✅ Collect and zip results
# -----------------------------
Write-Host "[+] Preparing results folder"

$resultsDir = "C:\results"
# Remove old results if they exist
Remove-Item -Path $resultsDir -Recurse -Force -ErrorAction SilentlyContinue
# Create a fresh folder
New-Item -ItemType Directory -Path $resultsDir | Out-Null

# -----------------------------
# Collect outputs from tools
# -----------------------------
Write-Host "[+] Collecting LOKI logs"
$lokiLogs = "C:\loki\loki\*.log"
Copy-Item -Path $lokiLogs -Destination $resultsDir -ErrorAction SilentlyContinue

# -----------------------------
# Create final ZIP for SFTP
# -----------------------------
$zipPath = "C:\results.zip"
if (Test-Path $zipPath) { Remove-Item -Path $zipPath -Force }
Compress-Archive -Path "$resultsDir\*" -DestinationPath $zipPath -Force

Write-Host "[+] DONE — Results ready at $zipPath"


