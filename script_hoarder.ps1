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
# 4️⃣ RETRIEVE RESULTS
# -----------------------------
Write-Host "[+] Retrieving results"
# Example SCP (assume SSH is ready)


Write-Host "=== DFIR Automation Script Finished ==="
