Write-Host "=== DFIR Automation Script Started ==="

# -----------------------------
# 1️⃣ DOWNLOAD TOOLS
# -----------------------------
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
# 2️⃣ CLONE HOARDER REPO
# -----------------------------
Write-Host "[+] Cloning Hoarder repository"
git clone --depth 1 https://github.com/DFIRKuiper/Hoarder.git C:\hoarder_temp
$hoarderDir = "C:\hoarder_temp\releases"

# -----------------------------
# 3️⃣ RUN TOOLS
# -----------------------------
Write-Host "[+] Running Hoarder (-vv)"
Set-Location $hoarderDir
.\hoarder.exe -vv

# -----------------------------
# ✅ Collect and zip results
# -----------------------------
Write-Host "[+] Preparing results folder"
$resultsDir = "C:\results"
Remove-Item -Path $resultsDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $resultsDir | Out-Null

# -----------------------------
# Collect only the ZIP output from Hoarder
# -----------------------------
Write-Host "[+] Collecting Hoarder ZIP output"
$hoarderZip = Get-ChildItem -Path $hoarderDir -Filter "*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($hoarderZip) {
    Copy-Item -Path $hoarderZip.FullName -Destination $resultsDir
    Write-Host "[+] Found and copied: $($hoarderZip.Name)"
} else {
    Write-Host "[!] WARNING: No ZIP file found in $hoarderDir"
}

# -----------------------------
# Create final ZIP for SFTP
# -----------------------------
$zipPath = "C:\results.zip"
if (Test-Path $zipPath) { Remove-Item -Path $zipPath -Force }
Compress-Archive -Path "$resultsDir\*" -DestinationPath $zipPath -Force

Write-Host "[+] DONE  Results ready at $zipPath"