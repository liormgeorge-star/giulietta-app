@echo off
rem PC Remote installer launcher: asks for administrator rights, then runs install.ps1.
cd /d "%~dp0"
if not exist "%~dp0install.ps1" (
  echo.
  echo   The files are not extracted yet.
  echo   Right-click pc-remote-windows.zip, choose "Extract All", then run install.cmd from the new folder.
  echo.
  pause
  exit /b 1
)
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo Asking for administrator rights...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
rem Files downloaded from the internet are marked as blocked; unblock ours before running.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%~dp0' -File | Unblock-File"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
echo.
pause
