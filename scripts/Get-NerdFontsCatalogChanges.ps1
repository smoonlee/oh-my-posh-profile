[CmdletBinding()]
param (
  [string] $PreviousCatalogPath,
  [Parameter(Mandatory)]
  [string] $CurrentCatalogPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $CurrentCatalogPath)) {
  throw "Current Nerd Fonts catalog not found: $CurrentCatalogPath"
}

$current = Get-Content -Path $CurrentCatalogPath -Raw | ConvertFrom-Json
$previous = if ($PreviousCatalogPath -and (Test-Path $PreviousCatalogPath)) {
  Get-Content -Path $PreviousCatalogPath -Raw | ConvertFrom-Json
} else {
  [pscustomobject]@{
    NerdFontsVersion = $null
    Fonts = @()
  }
}

$previousFonts = @($previous.Fonts)
$currentFonts = @($current.Fonts)
$previousByName = @{}
$currentByName = @{}

foreach ($font in $previousFonts) {
  $previousByName[[string]$font.FriendlyName] = $font
}
foreach ($font in $currentFonts) {
  $currentByName[[string]$font.FriendlyName] = $font
}

$added = @(
  $currentFonts |
    Where-Object { -not $previousByName.ContainsKey([string]$_.FriendlyName) } |
    Sort-Object FriendlyName
)
$removed = @(
  $previousFonts |
    Where-Object { -not $currentByName.ContainsKey([string]$_.FriendlyName) } |
    Sort-Object FriendlyName
)
$updated = @(
  foreach ($font in $currentFonts) {
    $oldFont = $previousByName[[string]$font.FriendlyName]
    if ($oldFont -and (
        [string]$oldFont.FontVersion -ne [string]$font.FontVersion -or
        [string]$oldFont.ArchiveName -ne [string]$font.ArchiveName
      )) {
      [pscustomobject]@{
        FriendlyName = [string]$font.FriendlyName
        OldVersion = [string]$oldFont.FontVersion
        NewVersion = [string]$font.FontVersion
        OldArchive = [string]$oldFont.ArchiveName
        NewArchive = [string]$font.ArchiveName
      }
    }
  }
)

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('Automated weekly update from https://www.nerdfonts.com/font-downloads.')
$lines.Add('')
$lines.Add('## Catalog summary')
$lines.Add('')
if ($previous.NerdFontsVersion) {
  $lines.Add("- Nerd Fonts release: ``$($previous.NerdFontsVersion)`` → ``$($current.NerdFontsVersion)``")
} else {
  $lines.Add("- Nerd Fonts release: ``$($current.NerdFontsVersion)``")
}
$lines.Add("- Font count: $($previousFonts.Count) → $($currentFonts.Count)")

$lines.Add('')
$lines.Add("### Added fonts ($($added.Count))")
$lines.Add('')
if ($added.Count -eq 0) {
  $lines.Add('_No fonts added._')
} else {
  foreach ($font in $added) {
    $lines.Add("- **$($font.FriendlyName)** — version ``$($font.FontVersion)`` (archive ``$($font.ArchiveName)``)")
  }
}

$lines.Add('')
$lines.Add("### Updated fonts ($($updated.Count))")
$lines.Add('')
if ($updated.Count -eq 0) {
  $lines.Add('_No font versions or archive names changed._')
} else {
  foreach ($font in $updated | Sort-Object FriendlyName) {
    $details = @()
    if ($font.OldVersion -ne $font.NewVersion) {
      $details += "version ``$($font.OldVersion)`` → ``$($font.NewVersion)``"
    }
    if ($font.OldArchive -ne $font.NewArchive) {
      $details += "archive ``$($font.OldArchive)`` → ``$($font.NewArchive)``"
    }
    $lines.Add("- **$($font.FriendlyName)** — $($details -join '; ')")
  }
}

$lines.Add('')
$lines.Add("### Removed fonts ($($removed.Count))")
$lines.Add('')
if ($removed.Count -eq 0) {
  $lines.Add('_No fonts removed._')
} else {
  foreach ($font in $removed) {
    $lines.Add("- **$($font.FriendlyName)** — previous version ``$($font.FontVersion)`` (archive ``$($font.ArchiveName)``)")
  }
}

$lines -join "`n"
