# Sync this repo into the Classic Era AddOns folder for in-game testing.
$ErrorActionPreference = "Stop"

$src = $PSScriptRoot
$dst = "C:\Program Files (x86)\World of Warcraft\_classic_era_\Interface\AddOns\LaucobsAchievements"

if (-not (Test-Path $dst)) {
  New-Item -ItemType Directory -Force -Path $dst | Out-Null
}

$files = @(
  "Alert.lua",
  "Core.lua",
  "Data.lua",
  "Share.lua",
  "Tracker.lua",
  "UI.lua",
  "LaucobsAchievements.toc"
)

foreach ($f in $files) {
  $from = Join-Path $src $f
  if (-not (Test-Path $from)) {
    Write-Warning "Missing: $f"
    continue
  }
  Copy-Item -Path $from -Destination (Join-Path $dst $f) -Force
  Write-Host "Synced $f"
}

Write-Host "Done. /reload in-game to pick up changes."
