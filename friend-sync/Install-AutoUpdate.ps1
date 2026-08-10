#Requires -Version 5.1
<#
.SYNOPSIS
  Install (or remove) a scheduled task that keeps the addon synced from GitHub.
#>
[CmdletBinding()]
param(
  [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$TaskName = "LaucobsAchievements GitHub Sync"
$Updater = Join-Path $PSScriptRoot "Update-Addon.ps1"

if (-not (Test-Path -LiteralPath $Updater)) {
  throw "Missing Update-Addon.ps1 next to this script."
}

if ($Uninstall) {
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
  Write-Host "Removed scheduled task '$TaskName'." -ForegroundColor Green
  Read-Host "Press Enter to close"
  exit 0
}

# Keep this folder wherever your friend puts it — the task points at absolute paths.
$action = New-ScheduledTaskAction `
  -Execute "powershell.exe" `
  -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Updater`" -Once -Quiet"

$triggers = @(
  (New-ScheduledTaskTrigger -AtLogOn),
  (New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddMinutes(5) -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration ([TimeSpan]::MaxValue))
)

$settings = New-ScheduledTaskSettingsSet `
  -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries `
  -StartWhenAvailable `
  -MultipleInstances IgnoreNew

$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask `
  -TaskName $TaskName `
  -Action $action `
  -Trigger $triggers `
  -Settings $settings `
  -Principal $principal `
  -Force | Out-Null

Write-Host ""
Write-Host "Installed scheduled task: $TaskName" -ForegroundColor Green
Write-Host "Runs at logon and about every hour. Updates only when GitHub has new commits."
Write-Host ""
Write-Host "To remove later, run:"
Write-Host "  powershell -File `"$PSCommandPath`" -Uninstall"
Write-Host ""

# Prime path detection / first sync now so the friend sees it work.
& $Updater -Once

Read-Host "Press Enter to close"
