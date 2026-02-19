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
# 4️⃣ COLLECT RESULTS
# -----------------------------
Write-Host "[+] Preparing result folder"

$results = "C:\results"
Remove-Item $results -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $results | Out-Null

Write-Host "[+] Collecting LOKI logs"
Copy-Item "C:\loki\loki\*.log" $results -ErrorAction SilentlyContinue

Write-Host "[+] Creating ZIP archive"
Compress-Archive -Path "$results\*" -DestinationPath "C:\dfir_results.zip" -Force

Write-Host "[+] DONE — Results ready at C:\dfir_results.zip"

