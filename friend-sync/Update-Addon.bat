@echo off
title Laucob's Achievements — Watching for updates
cd /d "%~dp0"
rem Default: keep running and sync whenever GitHub gets new commits.
rem One-shot: Update-Addon.bat -Once
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-Addon.ps1" %*
exit /b %ERRORLEVEL%
