@echo off
setlocal
rem Run the PowerShell bootstrap. Optional Ant targets can be passed as
rem space-separated arguments, e.g.: build.cmd fatjar
set "FILEBOT_ANT_ARGS=%*"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1"
exit /b %ERRORLEVEL%
