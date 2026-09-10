[CmdletBinding()]
param (
  [Parameter(Mandatory)]
  [string] $PreviousCatalogPath,
  [string] $RepositoryRoot = (Split-Path -Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'
$current = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'EndOfLifeProducts.json') -Raw | ConvertFrom-Json
$previous = Get-Content -LiteralPath $PreviousCatalogPath -Raw | ConvertFrom-Json
$added = @($current.Products | Where-Object { $_ -cnotin $previous.Products } | Sort-Object -Unique)
$removed = @($previous.Products | Where-Object { $_ -cnotin $current.Products } | Sort-Object -Unique)
if ($added.Count -eq 0 -and $removed.Count -eq 0) {
  Write-Host 'Product catalog unchanged; no release bump needed.'
  return
}

$manifestPath = Join-Path $RepositoryRoot 'src/modules/PwshProfile.EndOfLife/PwshProfile.EndOfLife.psd1'
$changelogPath = Join-Path $RepositoryRoot 'src/modules/PwshProfile.EndOfLife/CHANGELOG.md'
$manifest = [IO.File]::ReadAllText($manifestPath)
$changelog = [IO.File]::ReadAllText($changelogPath)
$modulePattern = "(?m)^(\s*ModuleVersion\s*=\s*)'(?<version>\d+\.\d+\.\d+)'"
if ([regex]::Matches($manifest, $modulePattern).Count -ne 1) {
  throw 'Expected one module version assignment.'
}
$oldModuleVersion = [version][regex]::Match($manifest, $modulePattern).Groups['version'].Value
$moduleVersion = '{0}.{1}.0' -f $oldModuleVersion.Major, ($oldModuleVersion.Minor + 1)
if ($changelog -match "(?m)^## \[$([regex]::Escape($moduleVersion))\]") {
  throw "Module changelog already contains $moduleVersion; reconcile the release version before retrying."
}
$heading = [regex]::Match($changelog, '(?m)^## \[')
if (-not $heading.Success) { throw 'No release heading found in CHANGELOG.md.' }
$notes = @(
  "## [$moduleVersion] - $([DateTime]::UtcNow.ToString('yyyy-MM-dd'))"
  ''
  '- Refresh the supported product catalog and tab completion from endoflife.date.'
)
if ($added.Count) { $notes += "- Added products: $(($added | ForEach-Object { '`{0}`' -f $_ }) -join ', ')." }
if ($removed.Count) { $notes += "- Removed products: $(($removed | ForEach-Object { '`{0}`' -f $_ }) -join ', ')." }
$notes += '- Lifecycle dates continue to be fetched live when queried.'
$newline = if ($changelog.Contains("`r`n")) { "`r`n" } else { "`n" }
$changelog = $changelog.Insert($heading.Index, (($notes -join $newline) + $newline + $newline))
$manifest = [regex]::Replace($manifest, $modulePattern, [Text.RegularExpressions.MatchEvaluator]{ param($m) $m.Groups[1].Value + "'$moduleVersion'" })
$utf8 = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText($manifestPath, $manifest, $utf8)
[IO.File]::WriteAllText($changelogPath, $changelog, $utf8)
Write-Host "Prepared independent PwshProfile.EndOfLife release $moduleVersion."
