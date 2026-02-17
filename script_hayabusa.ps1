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
# 4️⃣ RETRIEVE RESULTS
# -----------------------------
Write-Host "[+] Retrieving results"
# Example SCP (assume SSH is ready)


Write-Host "=== DFIR Automation Script Finished ==="
