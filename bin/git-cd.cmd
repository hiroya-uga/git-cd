@echo off

where pwsh.exe >nul 2>nul
if not errorlevel 1 (
  pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0git-cd.ps1" %*
  exit /b %errorlevel%
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0git-cd.ps1" %*
exit /b %errorlevel%
