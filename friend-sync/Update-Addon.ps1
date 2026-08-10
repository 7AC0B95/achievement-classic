#Requires -Version 5.1
<#
.SYNOPSIS
  Sync Laucob's Achievements from GitHub into your WoW Classic Era AddOns folder.

.DESCRIPTION
  No Git install required. Polls the public commits Atom feed (not the rate-limited
  GitHub REST API). When the tip commit changes, downloads only files listed in
  LaucobsAchievements/LaucobsAchievements.toc from raw.githubusercontent.com.

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
$TocFileName = "LaucobsAchievements.toc"
$UserAgent = "LaucobsAchievements-Updater"

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

function Save-SyncMarker([string]$Sha) {
  if (-not (Test-Path $StateDir)) {
    New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
  }
  @{
    sha      = $Sha
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

function Get-RawAddonUrl([string]$Sha, [string]$FileName) {
  return "https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Sha/$AddonFolderName/$FileName"
}

# Poll the public Atom feed - avoids api.github.com's 60 req/hour unauthenticated limit.
function Get-RemoteHeadSha {
  $url = "https://github.com/$RepoOwner/$RepoName/commits/$Branch.atom"
  $response = Invoke-WebRequest -Uri $url -Headers @{ "User-Agent" = $UserAgent } -UseBasicParsing -TimeoutSec 30
  $match = [regex]::Match($response.Content, "Grit::Commit/([0-9a-f]{40})")
  if (-not $match.Success) {
    throw "Could not parse latest commit from GitHub feed."
  }
  return $match.Groups[1].Value
}

function Get-RemoteText([string]$Url) {
  $response = Invoke-WebRequest -Uri $Url -Headers @{ "User-Agent" = $UserAgent } -UseBasicParsing -TimeoutSec 60
  return [string]$response.Content
}

function Get-AddonFileNamesFromToc([string]$TocText) {
  $names = New-Object System.Collections.Generic.List[string]
  $names.Add($TocFileName) | Out-Null

  foreach ($line in ($TocText -split "`r?`n")) {
    $trimmed = $line.Trim()
    if (-not $trimmed) { continue }
    if ($trimmed.StartsWith("#")) { continue }
    # Only plain addon files from this folder (ignore paths / nested oddities).
    if ($trimmed -match '[\\/]') { continue }
    if ($trimmed -notmatch '\.(lua|xml|toc|blp|tga|ogg|mp3)$') { continue }
    if (-not $names.Contains($trimmed)) {
      $names.Add($trimmed) | Out-Null
    }
  }

  return ,$names.ToArray()
}

function Get-ContentFingerprint([string]$Text) {
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $hash = $sha.ComputeHash($bytes)
    return ([BitConverter]::ToString($hash) -replace "-", "").ToLowerInvariant()
  }
  finally {
    $sha.Dispose()
  }
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

  Write-Step "Fetching $TocFileName ($shortSha)..."
  $tocText = Get-RemoteText (Get-RawAddonUrl -Sha $Sha -FileName $TocFileName)
  $fileNames = Get-AddonFileNamesFromToc -TocText $tocText

  $pending = @()
  $anyChanged = $false

  foreach ($name in $fileNames) {
    if ($name -eq $TocFileName) {
      $text = $tocText
    } else {
      $text = Get-RemoteText (Get-RawAddonUrl -Sha $Sha -FileName $name)
    }

    $dest = Join-Path $destAddon $name
    $remoteFp = Get-ContentFingerprint $text
    $localFp = $null
    if (Test-Path -LiteralPath $dest) {
      $localFp = Get-ContentFingerprint ([System.IO.File]::ReadAllText($dest))
    }

    if ($localFp -ne $remoteFp) {
      $anyChanged = $true
    }

    $pending += [pscustomobject]@{ Name = $name; Text = $text; Dest = $dest }
  }

  if (-not $anyChanged) {
    # Tip commit moved (e.g. friend-sync only) but addon files are identical.
    return "Skipped"
  }

  Write-Step "Updating addon files in $destAddon"
  $keep = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

  foreach ($item in $pending) {
    [void]$keep.Add($item.Name)
    Write-Host ("[{0}]   {1}" -f (Get-Date -Format "HH:mm:ss"), $item.Name) -ForegroundColor DarkGray
    # UTF-8 without BOM - matches typical Lua/TOC checkout.
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($item.Dest, $item.Text, $utf8)
  }

  Get-ChildItem -LiteralPath $destAddon -File -ErrorAction SilentlyContinue | ForEach-Object {
    if (-not $keep.Contains($_.Name)) {
      Write-Host ("[{0}]   removing stale {1}" -f (Get-Date -Format "HH:mm:ss"), $_.Name) -ForegroundColor DarkYellow
      Remove-Item -LiteralPath $_.FullName -Force
    }
  }

  Write-Ok "Updated to $shortSha. In-game: /reload"
  return "Updated"
}

function Sync-Addon {
  param(
    [Parameter(Mandatory = $true)]
    [string]$AddOnsPath,

    [switch]$VerboseStatus
  )

  $marker = Get-SyncMarker
  $lastSha = if ($marker -and $marker.sha) { [string]$marker.sha } else { $null }
  $destAddon = Join-Path $AddOnsPath $AddonFolderName

  $sha = Get-RemoteHeadSha
  $shortSha = $sha.Substring(0, [Math]::Min(7, $sha.Length))

  if ($lastSha -and ($lastSha -eq $sha) -and (Test-Path -LiteralPath $destAddon)) {
    if ($VerboseStatus) {
      Write-Ok "Already up to date ($shortSha)."
    }
    return "UpToDate"
  }

  $result = Install-AddonFiles -AddOnsPath $AddOnsPath -Sha $sha
  Save-SyncMarker -Sha $sha

  if ($result -eq "Skipped") {
    if ($VerboseStatus) {
      Write-Ok "Commit $shortSha has no addon file changes."
    }
    return "UpToDate"
  }

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

function Format-CheckError([string]$Message) {
  if ($Message -match '403|rate limit|Forbidden') {
    return "GitHub temporarily blocked the request (rate limit). Waiting, then retrying..."
  }
  return "Check failed: $Message - retrying in $IntervalSeconds s"
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
      Write-WarnLine (Format-CheckError $_.Exception.Message)
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
