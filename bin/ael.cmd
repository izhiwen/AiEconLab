@echo off
setlocal
set "AEL_POWERSHELL=powershell.exe"
where pwsh.exe >nul 2>nul
if %ERRORLEVEL% EQU 0 set "AEL_POWERSHELL=pwsh.exe"
"%AEL_POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0ael.ps1" %*
exit /b %ERRORLEVEL%
