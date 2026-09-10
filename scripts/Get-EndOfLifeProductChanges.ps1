[CmdletBinding()]
param (
  [string] $PreviousCatalogPath,
  [Parameter(Mandatory)]
  [string] $CurrentCatalogPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $CurrentCatalogPath)) {
  throw "Current endoflife.date product catalog not found: $CurrentCatalogPath"
}

$current = Get-Content -Path $CurrentCatalogPath -Raw | ConvertFrom-Json
$previous = if ($PreviousCatalogPath -and (Test-Path $PreviousCatalogPath)) {
  Get-Content -Path $PreviousCatalogPath -Raw | ConvertFrom-Json
} else {
  [pscustomobject]@{
    Products = @()
  }
}

$previousProducts = @($previous.Products | ForEach-Object { [string]$_ })
$currentProducts = @($current.Products | ForEach-Object { [string]$_ })
$previousSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$currentSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($product in $previousProducts) { [void]$previousSet.Add($product) }
foreach ($product in $currentProducts) { [void]$currentSet.Add($product) }

$added = @($currentProducts | Where-Object { -not $previousSet.Contains($_) } | Sort-Object)
$removed = @($previousProducts | Where-Object { -not $currentSet.Contains($_) } | Sort-Object)

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('Automated update from https://endoflife.date/api/all.json.')
$lines.Add('')
$lines.Add('## Product catalog summary')
$lines.Add('')
$lines.Add("- Product count: $($previousProducts.Count) → $($currentProducts.Count)")

$lines.Add('')
$lines.Add("### Added products ($($added.Count))")
$lines.Add('')
if ($added.Count -eq 0) {
  $lines.Add('_No products added._')
} else {
  foreach ($product in $added) {
    $lines.Add("- ``$product``")
  }
}

$lines.Add('')
$lines.Add("### Removed products ($($removed.Count))")
$lines.Add('')
if ($removed.Count -eq 0) {
  $lines.Add('_No products removed._')
} else {
  foreach ($product in $removed) {
    $lines.Add("- ``$product``")
  }
}

$lines -join "`n"
