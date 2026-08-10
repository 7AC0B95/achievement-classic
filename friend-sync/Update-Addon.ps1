#Requires -Version 5.1
<#
.SYNOPSIS
  Sync Laucob's Achievements from GitHub into your WoW Classic Era AddOns folder.

.DESCRIPTION
  No Git install required. Polls GitHub with a tiny conditional request (ETag).
  Unchanged checks return HTTP 304 and do not count against the API rate limit.
  When the commit changes, only files inside LaucobsAchievements/ are downloaded
  and written into the WoW AddOns folder (friend-sync and other repo files are ignored).

  Default mode watches continuously for active development.
#>
[CmdletBinding()]
param(
  # Check once and exit (used by the scheduled task).
  [switch]$Once,

  # Skip the "press Enter to close" pause.
  [switch]$Quiet,

  # How often to poll GitHub while watching (seconds). Minimum 5.
  [ValidateRange(5, 86400)]
  [int]$IntervalSeconds = 10
)

$ErrorActionPreference = "Stop"

$RepoOwner = "7AC0B95"
$RepoName = "achievement-classic"
$Branch = "main"
$AddonFolderName = "LaucobsAchievements"

$StateDir = Join-Path $env:LOCALAPPDATA "LaucobsAchievements"
$ConfigPath = Join-Path $StateDir "config.json"
$MarkerPath = Join-Path $StateDir "last-sync.json"

function Write-Step([string]$Message) {
  Clear-StatusLine
  Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message) -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
  Clear-StatusLine
  Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message) -ForegroundColor Green
}

function Write-WarnLine([string]$Message) {
  Clear-StatusLine
  Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message) -ForegroundColor Yellow
}

function Clear-StatusLine {
  if ($script:StatusActive) {
    Write-Host ("`r" + (" " * 72) + "`r") -NoNewline
    $script:StatusActive = $false
  }
}

function Show-WatchStatus([int]$Frame) {
  $spinners = @("|", "/", "-", "\")
  $spin = $spinners[$Frame % $spinners.Length]
  $msg = "  $spin  Watching for updates... (Ctrl+C to stop)"
  Write-Host ("`r" + $msg.PadRight(72)) -NoNewline -ForegroundColor DarkGray
  $script:StatusActive = $true
}

function Get-Config {
  if (-not (Test-Path $ConfigPath)) { return $null }
  try {
    return Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Save-Config([string]$AddOnsPath) {
  if (-not (Test-Path $StateDir)) {
    New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
  }
  @{ addOnsPath = $AddOnsPath } | ConvertTo-Json | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
}

function Find-ClassicEraAddOns {
  $roots = @(
    "${env:ProgramFiles(x86)}\World of Warcraft",
    "$env:ProgramFiles\World of Warcraft",
    "$env:USERPROFILE\World of Warcraft",
    "D:\World of Warcraft",
    "E:\World of Warcraft",
    "F:\World of Warcraft"
  )

  foreach ($root in $roots) {
    $candidate = Join-Path $root "_classic_era_\Interface\AddOns"
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }

  foreach ($drive in @("C:", "D:", "E:")) {
    if (-not (Test-Path "$drive\")) { continue }
    $wow = Get-ChildItem -Path "$drive\" -Filter "World of Warcraft" -Directory -ErrorAction SilentlyContinue |
      Select-Object -First 3
    foreach ($dir in $wow) {
      $candidate = Join-Path $dir.FullName "_classic_era_\Interface\AddOns"
      if (Test-Path -LiteralPath $candidate) {
        return $candidate
      }
    }
  }

  return $null
}

function Resolve-AddOnsPath {
  $config = Get-Config
  if ($config -and $config.addOnsPath -and (Test-Path -LiteralPath $config.addOnsPath)) {
    return $config.addOnsPath
  }

  $found = Find-ClassicEraAddOns
  if ($found) {
    Save-Config $found
    return $found
  }

  Write-WarnLine "Could not find Classic Era AddOns automatically."
  Write-Host "Paste the full path to your AddOns folder."
  Write-Host "Example: C:\Program Files (x86)\World of Warcraft\_classic_era_\Interface\AddOns"
  $manual = Read-Host "AddOns path"
  $manual = $manual.Trim().Trim('"')

  if (-not $manual) {
    throw "No AddOns path provided."
  }
  if (-not (Test-Path -LiteralPath $manual)) {
    throw "Path does not exist: $manual"
  }

  Save-Config $manual
  return $manual
}

function Get-SyncMarker {
  if (-not (Test-Path $MarkerPath)) { return $null }
  try {
    return Get-Content -LiteralPath $MarkerPath -Raw | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Save-SyncMarker([string]$Sha, [string]$ETag) {
  if (-not (Test-Path $StateDir)) {
    New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
  }
  @{
    sha      = $Sha
    etag     = $ETag
    syncedAt = (Get-Date).ToString("o")
    repo     = "https://github.com/$RepoOwner/$RepoName"
    branch   = $Branch
  } | ConvertTo-Json | Set-Content -LiteralPath $MarkerPath -Encoding UTF8
}

function Test-CanWrite([string]$Directory) {
  try {
    $probe = Join-Path $Directory (".laucobs-write-test-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType File -Path $probe -Force | Out-Null
    Remove-Item -LiteralPath $probe -Force
    return $true
  } catch {
    return $false
  }
}

function Get-HttpStatusCode($Exception) {
  $response = $Exception.Exception.Response
  if (-not $response) { return $null }
  try {
    return [int]$response.StatusCode
  } catch {
    return $null
  }
}

# Lightweight poll: conditional GET against the commits API.
# HTTP 304 (Not Modified) does not count against GitHub's rate limit.
function Get-RemoteHead {
  param([string]$ETag)

  $url = "https://api.github.com/repos/$RepoOwner/$RepoName/commits/$Branch"
  $headers = @{
    "User-Agent" = "LaucobsAchievements-Updater"
    "Accept"     = "application/vnd.github+json"
  }
  if ($ETag) {
    $headers["If-None-Match"] = $ETag
  }

  try {
    $response = Invoke-WebRequest -Uri $url -Headers $headers -UseBasicParsing -TimeoutSec 30
    $json = $response.Content | ConvertFrom-Json
    $newEtag = $response.Headers["ETag"]
    if ($newEtag -is [array]) { $newEtag = $newEtag[0] }
    return [pscustomobject]@{
      Changed = $true
      Sha     = [string]$json.sha
      ETag    = [string]$newEtag
    }
  }
  catch {
    $code = Get-HttpStatusCode $_
    if ($code -eq 304) {
      return [pscustomobject]@{
        Changed = $false
        Sha     = $null
        ETag    = $ETag
      }
    }
    throw
  }
}

function Test-CommitTouchesAddon([string]$Sha) {
  $url = "https://api.github.com/repos/$RepoOwner/$RepoName/commits/$Sha"
  $headers = @{
    "User-Agent" = "LaucobsAchievements-Updater"
    "Accept"     = "application/vnd.github+json"
  }

  $commit = Invoke-RestMethod -Uri $url -Headers $headers -TimeoutSec 30
  $prefix = "$AddonFolderName/"
  foreach ($file in @($commit.files)) {
    if ($file.filename -and ($file.filename.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase))) {
      return $true
    }
  }
  return $false
}

function Get-AddonRemoteFiles([string]$Sha) {
  $url = "https://api.github.com/repos/$RepoOwner/$RepoName/contents/$AddonFolderName`?ref=$Sha"
  $headers = @{
    "User-Agent" = "LaucobsAchievements-Updater"
    "Accept"     = "application/vnd.github+json"
  }

  $items = Invoke-RestMethod -Uri $url -Headers $headers -TimeoutSec 30
  # Single-file folders come back as one object, not an array.
  $files = @($items | Where-Object { $_.type -eq "file" -and $_.download_url })

  if ($files.Count -eq 0) {
    throw "No addon files found in '$AddonFolderName' at $Sha."
  }

  return $files
}

function Install-AddonFiles {
  param(
    [Parameter(Mandatory = $true)]
    [string]$AddOnsPath,

    [Parameter(Mandatory = $true)]
    [string]$Sha
  )

  $shortSha = $Sha.Substring(0, [Math]::Min(7, $Sha.Length))
  $destAddon = Join-Path $AddOnsPath $AddonFolderName

  if (-not (Test-Path -LiteralPath $destAddon)) {
    New-Item -ItemType Directory -Force -Path $destAddon | Out-Null
  }

  Write-Step "Fetching addon file list ($shortSha)..."
  $remoteFiles = Get-AddonRemoteFiles -Sha $Sha

  Write-Step "Updating $($remoteFiles.Count) file(s) in $destAddon"
  $keep = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

  foreach ($file in $remoteFiles) {
    $name = [string]$file.name
    [void]$keep.Add($name)
    $dest = Join-Path $destAddon $name
    Write-Host ("[{0}]   {1}" -f (Get-Date -Format "HH:mm:ss"), $name) -ForegroundColor DarkGray
    Invoke-WebRequest -Uri $file.download_url -OutFile $dest -UseBasicParsing -TimeoutSec 60
  }

  # Drop stale files in the addon folder only (never touches friend-sync / repo extras).
  Get-ChildItem -LiteralPath $destAddon -File -ErrorAction SilentlyContinue | ForEach-Object {
    if (-not $keep.Contains($_.Name)) {
      Write-Host ("[{0}]   removing stale {1}" -f (Get-Date -Format "HH:mm:ss"), $_.Name) -ForegroundColor DarkYellow
      Remove-Item -LiteralPath $_.FullName -Force
    }
  }

  Write-Ok "Updated to $shortSha. In-game: /reload"
}

function Sync-Addon {
  param(
    [Parameter(Mandatory = $true)]
    [string]$AddOnsPath,

    [switch]$VerboseStatus
  )

  $marker = Get-SyncMarker
  $etag = if ($marker -and $marker.etag) { [string]$marker.etag } else { $null }
  $lastSha = if ($marker -and $marker.sha) { [string]$marker.sha } else { $null }
  $destAddon = Join-Path $AddOnsPath $AddonFolderName

  $remote = Get-RemoteHead -ETag $etag

  if (-not $remote.Changed) {
    if ($VerboseStatus) {
      $short = if ($lastSha) { $lastSha.Substring(0, [Math]::Min(7, $lastSha.Length)) } else { "cached" }
      Write-Ok "Already up to date ($short)."
    }
    return "UpToDate"
  }

  $sha = $remote.Sha
  $shortSha = $sha.Substring(0, [Math]::Min(7, $sha.Length))

  # Same commit already installed - just refresh the ETag cache.
  if ($lastSha -and ($lastSha -eq $sha) -and (Test-Path -LiteralPath $destAddon)) {
    Save-SyncMarker -Sha $sha -ETag $remote.ETag
    if ($VerboseStatus) {
      Write-Ok "Already up to date ($shortSha)."
    }
    return "UpToDate"
  }

  # New commit, but only non-addon paths changed (e.g. friend-sync) - advance marker, skip download.
  if (-not (Test-CommitTouchesAddon -Sha $sha)) {
    Save-SyncMarker -Sha $sha -ETag $remote.ETag
    if ($VerboseStatus) {
      Write-Ok "Commit $shortSha has no addon file changes."
    }
    return "UpToDate"
  }

  Install-AddonFiles -AddOnsPath $AddOnsPath -Sha $sha
  Save-SyncMarker -Sha $sha -ETag $remote.ETag
  return "Updated"
}

function Wait-WithAnimation([int]$Seconds) {
  $frame = 0
  $end = [datetime]::UtcNow.AddSeconds($Seconds)
  while ([datetime]::UtcNow -lt $end) {
    Show-WatchStatus -Frame $frame
    $frame++
    Start-Sleep -Milliseconds 250
  }
}

function Show-WriteDeniedError {
  Write-Host ""
  Write-Host "ERROR: Cannot write to the AddOns folder." -ForegroundColor Red
  Write-Host "Run as administrator, or move WoW out of Program Files." -ForegroundColor Yellow
  Write-Host ""
}

try {
  Write-Host ""
  Write-Host "Laucob's Achievements - GitHub sync" -ForegroundColor White
  Write-Host ("=" * 42)

  $addOnsPath = Resolve-AddOnsPath
  Write-Step "AddOns folder: $addOnsPath"

  if (-not (Test-CanWrite $addOnsPath)) {
    throw [System.UnauthorizedAccessException] "WRITE_DENIED_ADDONS"
  }

  if ($Once) {
    Write-Step "Checking GitHub for updates..."
    [void](Sync-Addon -AddOnsPath $addOnsPath -VerboseStatus)
    if (-not $Quiet) {
      Write-Host ""
      Read-Host "Done. Press Enter to close"
    }
    exit 0
  }

  Write-Step "Watching GitHub ($Branch) every $IntervalSeconds seconds."
  Write-Host "Leave this window open. Press Ctrl+C to stop." -ForegroundColor Yellow
  Write-Host ""

  $script:StatusActive = $false
  $watchFrame = 0

  while ($true) {
    Show-WatchStatus -Frame $watchFrame
    $watchFrame++
    try {
      [void](Sync-Addon -AddOnsPath $addOnsPath)
    }
    catch {
      Write-WarnLine "Check failed: $($_.Exception.Message) - retrying in $IntervalSeconds s"
    }
    Wait-WithAnimation -Seconds $IntervalSeconds
  }
}
catch [System.UnauthorizedAccessException] {
  if ($_.Exception.Message -eq "WRITE_DENIED_ADDONS") {
    Show-WriteDeniedError
  } else {
    Write-Host ""
    Write-Host "Update failed: $($_.Exception.Message)" -ForegroundColor Red
  }
  if (-not $Quiet) {
    Read-Host "Press Enter to close"
  }
  exit 1
}
catch {
  Write-Host ""
  Write-Host "Update failed: $($_.Exception.Message)" -ForegroundColor Red
  if (-not $Quiet) {
    Write-Host ""
    Read-Host "Press Enter to close"
  }
  exit 1
}
