# Sync this repo into the Classic Era AddOns folder for in-game testing.
$ErrorActionPreference = "Stop"

$src = Join-Path $PSScriptRoot "ClassicGlory"
$dst = "C:\Program Files (x86)\World of Warcraft\_classic_era_\Interface\AddOns\ClassicGlory"
$legacy = "C:\Program Files (x86)\World of Warcraft\_classic_era_\Interface\AddOns\LaucobsAchievements"

if (-not (Test-Path $dst)) {
  New-Item -ItemType Directory -Force -Path $dst | Out-Null
}

$files = @(
  "Alert.lua",
  "Core.lua",
  "Data.lua",
  "Seal.lua",
  "Share.lua",
  "Tracker.lua",
  "UI.lua",
  "ClassicGlory.toc"
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

if (Test-Path $legacy) {
  Remove-Item -LiteralPath $legacy -Recurse -Force
  Write-Host "Removed old LaucobsAchievements folder"
}

Write-Host "Done. /reload in-game to pick up changes."
