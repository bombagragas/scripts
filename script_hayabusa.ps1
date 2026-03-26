Write-Host "=== DFIR Automation Script Started ==="

# -----------------------------
# 1️⃣ DOWNLOAD TOOLS
# -----------------------------

$zipPath     = "C:\hayabusa-3.8.0-win-x86.zip"
$extractPath = "C:\hayabusa"
$hayabusaExe = "C:\hayabusa\hayabusa-3.8.0-win-x86.exe"

if (Test-Path $hayabusaExe) {
    Write-Host "[~] Hayabusa already extracted, skipping download and extraction"
} else {
    if (Test-Path $zipPath) {
        Write-Host "[~] Hayabusa ZIP already downloaded, skipping download"
    } else {
        Write-Host "[+] Downloading Hayabusa"
        Invoke-WebRequest `
            -Uri "https://github.com/Yamato-Security/hayabusa/releases/download/v3.8.0/hayabusa-3.8.0-win-x86.zip" `
            -OutFile $zipPath
    }

    # -----------------------------
    # 2️⃣ EXTRACT & RENAME
    # -----------------------------

    Write-Host "[+] Extracting Hayabusa"
    Expand-Archive $zipPath $extractPath -Force
}


# -----------------------------
# 3️⃣ RUN TOOLS
# -----------------------------

Write-Host "[+] Running Hayabusa"

$logsPath  = "C:\Windows\System32\winevt\Logs"
$rulesPath = "C:\hayabusa\rules"
$outputJSON  = "C:\hayabusa\sec.json"
$outputHTML  = "C:\hayabusa\sec_summary.html"

& $hayabusaExe `
  json-timeline `
  --no-wizard `
  -d $logsPath `
  --sort `
  --profile timesketch-minimal `
  --rules $rulesPath `
  --output $outputJSON `
  -T `
  --clobber `
  --HTML-report $outputHTML



# -----------------------------
# ✅ Collect and zip results
# -----------------------------
Write-Host "[+] Preparing results folder"

$resultsDir = "C:\results"
Remove-Item -Path $resultsDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $resultsDir | Out-Null

Write-Host "[+] Collecting Hayabusa results"
Copy-Item -Path $outputJSON  -Destination $resultsDir -ErrorAction SilentlyContinue
Copy-Item -Path $outputHTML  -Destination $resultsDir -ErrorAction SilentlyContinue

# -----------------------------
# Create final ZIP for SFTP
# -----------------------------
$finalZip = "C:\results.zip"
if (Test-Path $finalZip) { Remove-Item -Path $finalZip -Force }
Compress-Archive -Path "$resultsDir\*" -DestinationPath $finalZip -Force

Write-Host "[+] DONE  Results ready at $finalZip"