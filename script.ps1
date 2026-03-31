Write-Host "=== DFIR Automation Script Started ==="

# -----------------------------
# 1️⃣ CHECK / INSTALL GIT
# -----------------------------
Write-Host "[+] Checking for Git..."
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    Write-Host "[+] Git not found. Installing Git..."
    $gitInstaller = "C:\git-installer.exe"
    Invoke-WebRequest `
        -Uri "https://github.com/git-for-windows/git/releases/latest/download/Git-2.42.0-64-bit.exe" `
        -OutFile $gitInstaller
    Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT", "/NORESTART" -Wait
    Remove-Item $gitInstaller

    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH", "User")
} else {
    Write-Host "[~] Git is already installed."
}

# -----------------------------
# 2️⃣ DOWNLOAD & EXTRACT LOKI
# -----------------------------
$lokiZip = "C:\loki_0.51.0.zip"
$lokiExe = "C:\loki\loki\loki.exe"
$lokiLog = "C:\loki\loki\loki_scan.log"

if (Test-Path $lokiExe) {
    Write-Host "[~] LOKI already extracted, skipping download and extraction"
} else {
    if (Test-Path $lokiZip) {
        Write-Host "[~] LOKI ZIP already downloaded, skipping download"
    } else {
        Write-Host "[+] Downloading LOKI..."
        Invoke-WebRequest `
            -Uri "https://github.com/Neo23x0/Loki/releases/latest/download/loki_0.51.0.zip" `
            -OutFile $lokiZip
    }
    Write-Host "[+] Extracting LOKI..."
    Expand-Archive $lokiZip "C:\loki" -Force
}

# -----------------------------
# 3️⃣ DOWNLOAD & EXTRACT HAYABUSA
# -----------------------------
$hayabusaZip = "C:\hayabusa-3.8.0-win-x86.zip"
$hayabusaExe = "C:\hayabusa\hayabusa-3.8.0-win-x86.exe"

if (Test-Path $hayabusaExe) {
    Write-Host "[~] Hayabusa already extracted, skipping download and extraction"
} else {
    if (Test-Path $hayabusaZip) {
        Write-Host "[~] Hayabusa ZIP already downloaded, skipping download"
    } else {
        Write-Host "[+] Downloading Hayabusa..."
        Invoke-WebRequest `
            -Uri "https://github.com/Yamato-Security/hayabusa/releases/download/v3.8.0/hayabusa-3.8.0-win-x86.zip" `
            -OutFile $hayabusaZip
    }
    Write-Host "[+] Extracting Hayabusa..."
    Expand-Archive $hayabusaZip "C:\hayabusa" -Force
}

# -----------------------------
# 4️⃣ CLONE HOARDER REPO
# -----------------------------
$hoarderTemp = "C:\hoarder_temp"
$hoarderDir  = "$hoarderTemp\releases"
$hoarderExe  = "$hoarderDir\hoarder.exe"

if (Test-Path $hoarderExe) {
    Write-Host "[~] Hoarder already cloned, skipping clone"
} else {
    if (Test-Path $hoarderTemp) {
        Write-Host "[+] Removing old hoarder_temp..."
        Remove-Item -Path $hoarderTemp -Recurse -Force
    }

    Write-Host "[+] Cloning Hoarder repository..."
    git clone --depth 1 https://github.com/DFIRKuiper/Hoarder.git $hoarderTemp

    if (-not (Test-Path $hoarderDir)) {
        Write-Host "[!] ERROR: Expected releases folder not found at $hoarderDir"
        Get-ChildItem $hoarderTemp | ForEach-Object { Write-Host "    $_" }
        exit 1
    }
}

# -----------------------------
# 5️⃣ PREPARE RESULTS FOLDER
# -----------------------------
Write-Host "[+] Preparing results folder..."
$resultsDir = "C:\results"

if (Test-Path $resultsDir) {
    Remove-Item -Path $resultsDir -Recurse -Force
}
New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null

# -----------------------------
# 6️⃣ RUN LOKI
# -----------------------------

# Clear previous log so it always overwrites
if (Test-Path $lokiLog) {
    Clear-Content -Path $lokiLog
    Write-Host "[~] Cleared previous LOKI log"
}

Write-Host "[+] Running LOKI..."
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

Write-Host "[+] Collecting LOKI logs..."
if (Test-Path $lokiLog) {
    Copy-Item -Path $lokiLog -Destination $resultsDir -Force
    Write-Host "[+] Copied: loki_scan.log"
} else {
    Write-Host "[!] WARNING: No LOKI log file found."
}

# -----------------------------
# 7️⃣ RUN HOARDER
# -----------------------------
Write-Host "[+] Running Hoarder (-vv)..."
Set-Location $hoarderDir

# ✅ Snapshot ZIPs before run
$zipsBefore = Get-ChildItem -Path $hoarderDir -Filter "*.zip" |
              Select-Object -ExpandProperty FullName

.\hoarder.exe -vv

# ✅ Wait a moment to ensure file is flushed to disk
Start-Sleep -Seconds 3

Write-Host "[+] Collecting Hoarder ZIP..."
$newZips = Get-ChildItem -Path $hoarderDir -Filter "*.zip" |
           Where-Object { $zipsBefore -notcontains $_.FullName } |
           Sort-Object LastWriteTime -Descending

if ($newZips) {
    foreach ($zip in $newZips) {
        Copy-Item -Path $zip.FullName -Destination $resultsDir -Force
        Write-Host "[+] Copied ZIP: $($zip.Name)"
    }
} else {
    # ✅ Fallback: grab the most recently modified ZIP regardless
    Write-Host "[!] WARNING: No new ZIP detected, falling back to latest ZIP in $hoarderDir"
    $fallbackZip = Get-ChildItem -Path $hoarderDir -Filter "*.zip" |
                   Sort-Object LastWriteTime -Descending |
                   Select-Object -First 1
    if ($fallbackZip) {
        Copy-Item -Path $fallbackZip.FullName -Destination $resultsDir -Force
        Write-Host "[+] Copied fallback ZIP: $($fallbackZip.Name)"
    } else {
        Write-Host "[!] WARNING: No ZIP found at all in $hoarderDir"
        Write-Host "[i] Contents of releases folder:"
        Get-ChildItem $hoarderDir | ForEach-Object { Write-Host "    $($_.FullName)" }
    }
}

# -----------------------------
# 8️⃣ RUN HAYABUSA
# -----------------------------
Write-Host "[+] Running Hayabusa..."
$logsPath   = "C:\Windows\System32\winevt\Logs"
$rulesPath  = "C:\hayabusa\rules"
$outputJson = "C:\hayabusa\sec.json"
$outputHTML = "C:\hayabusa\sec_summary.html"

& $hayabusaExe `
    json-timeline `
    --no-wizard `
    -d $logsPath `
    --sort `
    --profile timesketch-minimal `
    --rules $rulesPath `
    --output $outputJson `
    -T `
    --clobber `
    --HTML-report $outputHTML

Write-Host "[+] Collecting Hayabusa results..."
foreach ($file in @($outputJson, $outputHTML)) {
    if (Test-Path $file) {
        Copy-Item -Path $file -Destination $resultsDir -Force
        Write-Host "[+] Copied: $(Split-Path $file -Leaf)"
    } else {
        Write-Host "[!] WARNING: Expected Hayabusa output not found: $file"
    }
}

# -----------------------------
# 9️⃣ CREATE FINAL ZIP
# -----------------------------
$zipPath = "C:\results.zip"
if (Test-Path $zipPath) { Remove-Item -Path $zipPath -Force }

$resultItems = Get-ChildItem -Path $resultsDir
if ($resultItems) {
    Compress-Archive -Path "$resultsDir\*" -DestinationPath $zipPath -Force
    Write-Host "[+] DONE - Results ready at $zipPath"
    Write-Host "[i] Final contents:"
    $resultItems | ForEach-Object { Write-Host "    $($_.Name)" }
} else {
    Write-Host "[!] WARNING: Results folder is empty - skipping ZIP creation."
}