Write-Host "=== DFIR Automation Script Started ==="

# -----------------------------
# 1️⃣ DOWNLOAD TOOLS
# -----------------------------

Write-Host "[+] Downloading Hayabusa"
Invoke-WebRequest `
 -Uri "https://github.com/Yamato-Security/hayabusa/releases/download/v3.8.0/hayabusa-3.8.0-win-x86.zip" `
 -OutFile "C:\hayabusa-3.8.0-win-x86.zip"


# -----------------------------
# 2️⃣ EXTRACT & RENAME
# -----------------------------

Write-Host "[+] Extracting Hayabusa"
Expand-Archive "C:\hayabusa-3.8.0-win-x86.zip" "C:\hayabusa" -Force



# -----------------------------
# 3️⃣ RUN TOOLS
# -----------------------------

Write-Host "[+] Running Hayabusa"

$hayabusaExe = "C:\hayabusa\hayabusa-3.8.0-win-x86.exe"
$logsPath    = "C:\Windows\System32\winevt\Logs"
$rulesPath   = "C:\hayabusa\rules"
$outputjson   = "C:\hayabusa\sec.json"
$outputHTML  = "C:\hayabusa\sec_summary.html"

& $hayabusaExe `
  csv-timeline `
  --no-wizard `
  -d $logsPath `
  --sort `
  --profile timesketch-minimal `
  --rules $rulesPath `
  --output $outputjson `
  -T `
  --HTML-report $outputHTML



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

Write-Host "[+] Collecting Hayabusa results"
Copy-Item -Path "C:\hayabusa\sec.json" -Destination $resultsDir -ErrorAction SilentlyContinue
Copy-Item -Path "C:\hayabusa\sec_summary.html" -Destination $resultsDir -ErrorAction SilentlyContinue


# -----------------------------
# Create final ZIP for SFTP
# -----------------------------
$zipPath = "C:\results.zip"
if (Test-Path $zipPath) { Remove-Item -Path $zipPath -Force }
Compress-Archive -Path "$resultsDir\*" -DestinationPath $zipPath -Force

Write-Host "[+] DONE  Results ready at $zipPath"


