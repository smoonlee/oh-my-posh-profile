[CmdletBinding()]
param (
  [string] $ProductsUrl = 'https://endoflife.date/api/all.json',
  [string] $CatalogPath = (Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'EndOfLifeProducts.json'),
  [string] $ModuleScriptPath = (Join-Path (Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'src') 'modules\PwshProfile.EndOfLife\PwshProfile.EndOfLife.psm1')
)

$ErrorActionPreference = 'Stop'
$headers = @{ 'User-Agent' = 'oh-my-posh-profile-endoflife-updater' }

Write-Host "Reading endoflife.date product list from $ProductsUrl"
$response = Invoke-RestMethod -Uri $ProductsUrl -Headers $headers -ErrorAction Stop
$products = @(
  $response |
    Write-Output |
    ForEach-Object { [string]$_ } |
    Where-Object { $_ -match '^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$' } |
    Sort-Object -Unique
)

if ($products.Count -lt 100) {
  throw "Only $($products.Count) products were returned; the endoflife.date API response may have changed."
}

$catalog = [ordered]@{
  SourceUrl = $ProductsUrl
  ProductCount = $products.Count
  Products = $products
}

$catalogJson = $catalog | ConvertTo-Json -Depth 4
[System.IO.File]::WriteAllText(
  [System.IO.Path]::GetFullPath($CatalogPath),
  "$catalogJson`n",
  [System.Text.UTF8Encoding]::new($false)
)

$moduleScript = [System.IO.File]::ReadAllText([System.IO.Path]::GetFullPath($ModuleScriptPath))
$indent = '    '
$startMarker = "$indent# BEGIN GENERATED END-OF-LIFE PRODUCT VALIDATESET"
$endMarker = "$indent# END GENERATED END-OF-LIFE PRODUCT VALIDATESET"
$generatedValues = $products | ForEach-Object {
  $escapedName = $_ -replace "'", "''"
  "{0}{0}'{1}'" -f $indent, $escapedName
}
$generatedBlock = @(
  $startMarker
  "$indent[ValidateSet("
  ($generatedValues -join ",`n")
  "$indent)]"
  "$indent[Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Query')]"
  "$indent[Alias('Product')]"
  "$indent[string] `$ProductName"
  $endMarker
) -join "`n"

$markerPattern = '(?ms)^[ \t]*# BEGIN GENERATED END-OF-LIFE PRODUCT VALIDATESET.*?^[ \t]*# END GENERATED END-OF-LIFE PRODUCT VALIDATESET'
if ($moduleScript -notmatch $markerPattern) {
  throw "Generated end-of-life product markers were not found in '$ModuleScriptPath'."
}

$updatedModuleScript = [regex]::Replace($moduleScript, $markerPattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $generatedBlock })
[System.IO.File]::WriteAllText(
  [System.IO.Path]::GetFullPath($ModuleScriptPath),
  $updatedModuleScript,
  [System.Text.UTF8Encoding]::new($false)
)

Write-Host "Generated $($products.Count) endoflife.date products."
