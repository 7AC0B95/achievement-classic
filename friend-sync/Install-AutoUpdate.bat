@echo off
title Laucob's Achievements — Install auto-update
cd /d "%~dp0"

echo.
echo This creates a Windows Scheduled Task that runs the updater
echo every hour while you are logged in (and once at logon).
echo No extra software is installed.
echo.
pause

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-AutoUpdate.ps1"
exit /b %ERRORLEVEL%
