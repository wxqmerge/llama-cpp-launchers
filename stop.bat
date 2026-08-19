@echo off
setlocal
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"name='llama-server.exe'\" | ForEach-Object { Write-Host \"Stopping llama-server PID $($_.ProcessId)\"; Stop-Process -Id $_.ProcessId -Force }"
endlocal
