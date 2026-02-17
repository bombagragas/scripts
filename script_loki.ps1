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
# 4️⃣ RETRIEVE RESULTS
# -----------------------------
Write-Host "[+] Retrieving results"
# Example SCP (assume SSH is ready)


Write-Host "=== DFIR Automation Script Finished ==="
