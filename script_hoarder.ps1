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
# 3️⃣ CLONE HOARDER REPO
# -----------------------------
Write-Host "[+] Cloning Hoarder repository"
# Shallow clone to save time
git clone --depth 1 https://github.com/DFIRKuiper/Hoarder.git C:\hoarder_temp
$hoarderDir = "C:\hoarder_temp\releases"



# -----------------------------
# 2️⃣ EXTRACT & RENAME
# -----------------------------



# -----------------------------
# 3️⃣ RUN TOOLS
# -----------------------------


Write-Host "[+] Running Hoarder (-vv)"
Set-Location $hoarderDir
.\hoarder.exe -vv





# -----------------------------
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
Write-Host "[+] Collecting Hoarder results"
$hoarderSource = "C:\hoarder_temp\releases\*"
$hoarderDest   = Join-Path $resultsDir "hoarder"
New-Item -ItemType Directory -Path $hoarderDest -Force | Out-Null
Copy-Item -Path $hoarderSource -Destination $hoarderDest -Recurse -ErrorAction SilentlyContinue

# -----------------------------
# Create final ZIP for SFTP
# -----------------------------
$zipPath = "C:\results.zip"
if (Test-Path $zipPath) { Remove-Item -Path $zipPath -Force }
Compress-Archive -Path "$resultsDir\*" -DestinationPath $zipPath -Force

Write-Host "[+] DONE  Results ready at $zipPath"


