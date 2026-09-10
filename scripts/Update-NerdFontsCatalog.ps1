[CmdletBinding()]
param (
  [string] $DownloadsUrl = 'https://www.nerdfonts.com/font-downloads',
  [string] $FontDataUrl = 'https://raw.githubusercontent.com/ryanoasis/nerd-fonts/gh-pages/_data/fonts.json',
  [string] $CatalogPath = (Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'NerdFontsCatalog.json'),
  [string] $SetupScriptPath = (Join-Path (Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'src') 'Invoke-PwshProfileSetup.ps1')
)

$ErrorActionPreference = 'Stop'
$headers = @{ 'User-Agent' = 'oh-my-posh-profile-catalog-updater' }

Write-Host "Reading Nerd Fonts downloads from $DownloadsUrl"
$page = (Invoke-WebRequest -Uri $DownloadsUrl -Headers $headers -UseBasicParsing).Content
$fontData = Invoke-RestMethod -Uri $FontDataUrl -Headers $headers

$linkPattern = '<a[^>]+href=["''](?<url>https://github\.com/ryanoasis/nerd-fonts/releases/download/(?<release>v[^/"'']+)/(?<archive>[^/"'']+)\.zip)["''][^>]*>(?<friendly>.*?)</a>'
$linkMatches = [regex]::Matches(
  $page,
  $linkPattern,
  [System.Text.RegularExpressions.RegexOptions]'IgnoreCase,Singleline'
)

$downloads = foreach ($match in $linkMatches) {
  $friendlyName = [System.Net.WebUtility]::HtmlDecode(
    ($match.Groups['friendly'].Value -replace '<[^>]+>', '').Trim()
  )

  if ($friendlyName -and $friendlyName -ne 'Download') {
    [pscustomobject]@{
      FriendlyName = $friendlyName
      ArchiveName = [System.Uri]::UnescapeDataString($match.Groups['archive'].Value)
      Release = $match.Groups['release'].Value
      DownloadUrl = $match.Groups['url'].Value
    }
  }
}

$downloads = @($downloads | Sort-Object ArchiveName -Unique)
if ($downloads.Count -lt 50) {
  throw "Only $($downloads.Count) fonts were scraped; the Nerd Fonts page structure may have changed."
}

$releaseVersions = @($downloads.Release | Sort-Object -Unique)
if ($releaseVersions.Count -ne 1) {
  throw "Expected one Nerd Fonts release version but found: $($releaseVersions -join ', ')"
}

$metadataByFolder = @{}
foreach ($font in $fontData.fonts) {
  $metadataByFolder[[string]$font.folderName] = $font
}

$fonts = foreach ($download in $downloads) {
  $metadata = $metadataByFolder[$download.ArchiveName]
  if (-not $metadata) {
    throw "No fonts.json metadata found for archive '$($download.ArchiveName)'."
  }

  [pscustomobject][ordered]@{
    FriendlyName = $download.FriendlyName
    ArchiveName = $download.ArchiveName
    FontVersion = [string]$metadata.version
    DownloadUrl = $download.DownloadUrl
  }
}

$catalog = [ordered]@{
  SourceUrl = $DownloadsUrl
  NerdFontsVersion = $releaseVersions[0]
  Fonts = @($fonts | Sort-Object FriendlyName)
}

$catalogJson = $catalog | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText(
  [System.IO.Path]::GetFullPath($CatalogPath),
  "$catalogJson`n",
  [System.Text.UTF8Encoding]::new($false)
)

$setupScript = [System.IO.File]::ReadAllText([System.IO.Path]::GetFullPath($SetupScriptPath))
$indent = "`t"
$startMarker = "$indent# BEGIN GENERATED NERD FONT VALIDATESET"
$endMarker = "$indent# END GENERATED NERD FONT VALIDATESET"
$generatedValues = $catalog.Fonts | ForEach-Object {
  $escapedName = $_.FriendlyName -replace "'", "''"
  "{0}{0}'{1}'" -f $indent, $escapedName
}
$generatedBlock = @(
  $startMarker
  "$indent[ValidateSet("
  ($generatedValues -join ",`n")
  "$indent)]"
  "$indent[Parameter(Position = 0)]"
  "$indent[Alias('NerdFont')]"
  "$indent[string] `$nerdFontName = ''"
  $endMarker
) -join "`n"

$markerPattern = '(?ms)^[ \t]*# BEGIN GENERATED NERD FONT VALIDATESET.*?^[ \t]*# END GENERATED NERD FONT VALIDATESET'
if ($setupScript -notmatch $markerPattern) {
  throw "Generated Nerd Font markers were not found in '$SetupScriptPath'."
}

$updatedSetupScript = [regex]::Replace($setupScript, $markerPattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $generatedBlock })
[System.IO.File]::WriteAllText(
  [System.IO.Path]::GetFullPath($SetupScriptPath),
  $updatedSetupScript,
  [System.Text.UTF8Encoding]::new($false)
)

Write-Host "Generated $($fonts.Count) fonts for Nerd Fonts $($catalog.NerdFontsVersion)."
