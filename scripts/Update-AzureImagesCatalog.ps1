[CmdletBinding()]
param (
    [string] $RepositoryRoot = (Split-Path -Path $PSScriptRoot -Parent),
    [string] $Subscription,
    [switch] $EmbedOnly,
    [switch] $PrepareRelease,
    [switch] $AllowLargeRemoval
)

$ErrorActionPreference = 'Stop'
$catalogPath = Join-Path $RepositoryRoot 'AzureImagesCatalog.json'
$moduleRoot = Join-Path $RepositoryRoot 'src/modules/PwshProfile.AzureImages'
$scriptPath = Join-Path $moduleRoot 'PwshProfile.AzureImages.psm1'
$manifestPath = Join-Path $moduleRoot 'PwshProfile.AzureImages.psd1'
$changelogPath = Join-Path $moduleRoot 'CHANGELOG.md'
$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
if ($catalog.SchemaVersion -ne 1 -or $catalog.Cloud -ne 'AzureCloud' -or
    $catalog.Locations -isnot [array] -or -not $catalog.Locations.Count -or
    $catalog.Presets -isnot [array] -or -not $catalog.Presets.Count -or
    $catalog.Images -isnot [array]) {
    throw 'Expected a schemaVersion 1 public Azure catalogue with Locations, Presets and Images arrays.'
}
foreach ($location in $catalog.Locations) {
    if ($location -notmatch '\A[a-z0-9]+\z') { throw "Invalid catalogue location: $location" }
}
if (@($catalog.Locations | Sort-Object -Unique).Count -ne $catalog.Locations.Count) { throw 'Duplicate catalogue locations.' }
if (-not $catalog.PSObject.Properties['Lifecycles']) {
    $catalog | Add-Member -NotePropertyName Lifecycles -NotePropertyValue @()
}
if ($catalog.Lifecycles -isnot [array]) { throw 'Expected a lifecycle array in the catalogue.' }
if (-not $catalog.PSObject.Properties['AvailableLocations']) {
    $catalog | Add-Member -NotePropertyName AvailableLocations -NotePropertyValue @($catalog.Locations)
}
if ($catalog.AvailableLocations -isnot [array] -or -not $catalog.AvailableLocations.Count -or
    @($catalog.AvailableLocations | Where-Object { $_ -isnot [string] -or $_ -notmatch '\A[a-z0-9]+\z' }).Count -or
    @($catalog.AvailableLocations | Sort-Object -Unique).Count -ne $catalog.AvailableLocations.Count) {
    throw 'Invalid or duplicate available region names.'
}
$presetKeys = @{}
foreach ($preset in $catalog.Presets) {
    if ($preset.OS -notmatch '\A[a-zA-Z0-9]+\z' -or $preset.OS -eq 'All' -or
        $preset.Publisher -notmatch '\A[a-zA-Z0-9._-]+\z' -or
        $preset.Offer -notmatch '\A[a-zA-Z0-9._*?-]+\z') { throw 'Invalid catalogue OS/publisher/offer mapping.' }
    $key = '{0}|{1}|{2}' -f $preset.OS, $preset.Publisher, $preset.Offer
    if ($presetKeys.ContainsKey($key)) { throw "Duplicate catalogue preset: $key" }
    $presetKeys[$key] = $true
}

$moduleScript = [IO.File]::ReadAllText($scriptPath)
$embeddedPattern = "(?ms)^\`$script:AzureImagesCatalog = @'\r?\n(?<json>.*?)^'@ \| ConvertFrom-Json"
$embeddedMatches = [regex]::Matches($moduleScript, $embeddedPattern)
if ($embeddedMatches.Count -ne 1) { throw 'Expected exactly one embedded Azure image catalogue.' }
$previous = $embeddedMatches[0].Groups['json'].Value | ConvertFrom-Json
$previousJson = $previous | ConvertTo-Json -Depth 10 -Compress

if (-not $EmbedOnly) {
    $imageModule = Import-Module $manifestPath -Force -PassThru -Scope Local
    $activeCloud = @(& $imageModule { Invoke-AzureImagesCli -Arguments @('cloud', 'show', '--query', '[name]') })
    if ($activeCloud.Count -ne 1 -or $activeCloud[0] -ne $catalog.Cloud) {
        throw "The active Azure CLI cloud does not match '$($catalog.Cloud)'. Catalogue was not changed."
    }
    $regionArguments = @('account', 'list-locations', '--query', "[?metadata.regionType=='Physical'].name")
    if ($Subscription) { $regionArguments += @('--subscription', $Subscription) }
    $regions = @(& $imageModule { param($arguments) Invoke-AzureImagesCli -Arguments $arguments } $regionArguments)
    if (-not $regions.Count -or @($regions | Where-Object { $_ -isnot [string] -or $_ -notmatch '\A[a-z0-9]+\z' }).Count) {
        throw 'Azure returned an empty or invalid region list. Catalogue was not changed.'
    }
    $regions = @($regions | Sort-Object -Unique)
    $removedRegions = @($previous.AvailableLocations | Where-Object { $_ -notin $regions })
    if ($removedRegions.Count -and -not $AllowLargeRemoval) {
        throw "Region discovery would remove $($removedRegions -join ', '). Investigate before using -AllowLargeRemoval. Catalogue was not changed."
    }
    $catalog.AvailableLocations = $regions
    $catalog.Lifecycles = @(& $imageModule {
            foreach ($product in $script:AzureImageLifecycleProducts) { Get-AzureImageLifecycleData -Product $product }
        } | Sort-Object Product, Cycle)
    $lifecycleKeys = @{}
    foreach ($entry in $catalog.Lifecycles) { $lifecycleKeys['{0}|{1}' -f $entry.Product, $entry.Cycle] = $true }
    $removedLifecycles = @($previous.Lifecycles | Where-Object { $_ -and -not $lifecycleKeys.ContainsKey(('{0}|{1}' -f $_.Product, $_.Cycle)) })
    if ($removedLifecycles.Count -and -not $AllowLargeRemoval) {
        throw 'Refresh would remove lifecycle records. Investigate before using -AllowLargeRemoval. Catalogue was not changed.'
    }
    $images = @{}
    foreach ($location in $catalog.Locations) {
        $arguments = @('vm', 'image', 'list-publishers', '--location', $location)
        if ($Subscription) { $arguments += @('--subscription', $Subscription) }
        $publishers = @(& $imageModule { param($arguments) Invoke-AzureImagesCli -Arguments $arguments } $arguments)
        if (-not $publishers.Count) { throw "No image publishers returned for '$location'. Catalogue was not changed." }
        $regionCount = 0
        foreach ($preset in $catalog.Presets) {
            if ($preset.Publisher -notin $publishers.name) {
                Write-Warning "Publisher '$($preset.Publisher)' is not listed in '$location'; skipping $($preset.OS)."
                continue
            }
            $query = @{ Location = $location; Publisher = $preset.Publisher; Offer = $preset.Offer; Expanded = $true; IncludeMetadata = $true; IncludeUnsupported = $true }
            if ($Subscription) { $query.Subscription = $Subscription }
            Write-Host "Querying $($preset.OS): $($preset.Publisher)/$($preset.Offer) in $location"
            $results = @(& $imageModule { param($query) Get-AzureVmImage @query } $query)
            foreach ($image in $results) {
                $key = '{0}|{1}|{2}|{3}|{4}' -f $preset.OS, $location, $image.Publisher, $image.Offer, $image.Sku
                $images[$key] = [pscustomobject][ordered]@{
                    OS           = $preset.OS
                    Location     = $location
                    Publisher    = $image.Publisher
                    Offer        = $image.Offer
                    Sku          = $image.Sku
                    Version      = 'latest'
                    Urn          = $image.Urn
                    Architecture = $image.Architecture
                    Generation   = $image.Generation
                }
                $regionCount++
            }
        }
        if (-not $regionCount) { throw "No matching images returned for '$location'. Catalogue was not changed." }
    }
    $removed = @($previous.Images | Where-Object {
            $key = '{0}|{1}|{2}|{3}|{4}' -f $_.OS, $_.Location, $_.Publisher, $_.Offer, $_.Sku
            -not $images.ContainsKey($key)
        })
    if ($previous.Images.Count -gt 0 -and $removed.Count / $previous.Images.Count -gt 0.25 -and -not $AllowLargeRemoval) {
        throw "Refresh would remove $($removed.Count) of $($previous.Images.Count) images. Investigate before using -AllowLargeRemoval. Catalogue was not changed."
    }
    $catalog.Images = @($images.Values | Sort-Object OS, Location, Publisher, Offer, Sku)
}

$lifecycleKeys = @{}
foreach ($entry in $catalog.Lifecycles) {
    if ($entry.Product -notmatch '\A[a-z0-9-]+\z' -or $entry.Cycle -notmatch '\A[a-zA-Z0-9._-]+\z') { throw 'Invalid lifecycle product or cycle.' }
    $key = '{0}|{1}' -f $entry.Product, $entry.Cycle
    if ($lifecycleKeys.ContainsKey($key)) { throw "Duplicate lifecycle record: $key" }
    $lifecycleKeys[$key] = $true
    $parsedDate = [datetime]::MinValue
    if (-not [datetime]::TryParseExact([string]$entry.ReleaseDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsedDate)) { throw 'Invalid lifecycle release date.' }
    if ($entry.Eol -isnot [bool] -and -not [datetime]::TryParseExact([string]$entry.Eol, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsedDate)) { throw 'Invalid lifecycle end-of-life date.' }
}

$imageKeys = @{}
foreach ($image in $catalog.Images) {
    foreach ($property in @('Architecture', 'Generation')) {
        if (-not $image.PSObject.Properties[$property]) {
            $image | Add-Member -NotePropertyName $property -NotePropertyValue 'Unknown'
        }
    }
    if ($image.Architecture -notin @('amd64', 'arm64', 'Unknown') -or $image.Generation -notin @('Gen1', 'Gen2', 'Unknown')) {
        throw 'Invalid image architecture or generation in catalogue.'
    }
    foreach ($property in @('Publisher', 'Offer', 'Sku')) {
        if ($image.$property -notmatch '\A[a-zA-Z0-9._-]+\z') { throw "Invalid image $property in catalogue." }
    }
    $expectedUrn = '{0}:{1}:{2}:latest' -f $image.Publisher, $image.Offer, $image.Sku
    if ($image.Version -cne 'latest' -or $image.Urn -cne $expectedUrn -or $image.Location -notin $catalog.Locations) {
        throw 'Image version, URN or location is inconsistent with the catalogue.'
    }
    $matchingPreset = @($catalog.Presets | Where-Object {
            $_.OS -eq $image.OS -and $_.Publisher -eq $image.Publisher -and $image.Offer -like $_.Offer
        })
    if (-not $matchingPreset.Count) { throw 'Catalogue image does not match a configured OS preset.' }
    $key = '{0}|{1}|{2}|{3}|{4}' -f $image.OS, $image.Location, $image.Publisher, $image.Offer, $image.Sku
    if ($imageKeys.ContainsKey($key)) { throw "Duplicate catalogue image: $key" }
    $imageKeys[$key] = $true
}

$json = $catalog | ConvertTo-Json -Depth 10
$changed = ($catalog | ConvertTo-Json -Depth 10 -Compress) -cne $previousJson
$replacement = "`$script:AzureImagesCatalog = @'`n$json`n'@ | ConvertFrom-Json"
$updatedScript = [regex]::Replace($moduleScript, $embeddedPattern, [Text.RegularExpressions.MatchEvaluator] { param($match) $replacement })
$tokens = $null
$parseErrors = $null
$null = [Management.Automation.Language.Parser]::ParseInput($updatedScript, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors.Message -join '; ') }

$writes = [ordered]@{ $catalogPath = "$json`n"; $scriptPath = $updatedScript }
$computeRoot = Join-Path $RepositoryRoot 'src/modules/PwshProfile.AzureCompute'
$computeScriptPath = Join-Path $computeRoot 'PwshProfile.AzureCompute.psm1'
$computeScript = [IO.File]::ReadAllText($computeScriptPath)
$computePattern = "(?ms)^\`$script:AzureComputeLocations = @'\r?\n(?<json>.*?)^'@ \| ConvertFrom-Json"
$computeMatches = [regex]::Matches($computeScript, $computePattern)
if ($computeMatches.Count -ne 1) { throw 'Expected exactly one embedded Compute region list.' }
$previousRegions = ConvertFrom-Json -InputObject $computeMatches[0].Groups['json'].Value
$computeChanged = (@($previousRegions | Sort-Object) -join ',') -cne (@($catalog.AvailableLocations | Sort-Object) -join ',')
$regionJson = ConvertTo-Json -InputObject @($catalog.AvailableLocations)
$computeReplacement = "`$script:AzureComputeLocations = @'`n$regionJson`n'@ | ConvertFrom-Json"
$updatedComputeScript = [regex]::Replace($computeScript, $computePattern, [Text.RegularExpressions.MatchEvaluator] { param($match) $computeReplacement })
$null = [Management.Automation.Language.Parser]::ParseInput($updatedComputeScript, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors.Message -join '; ') }
if ($computeChanged) { $writes[$computeScriptPath] = $updatedComputeScript }
$releaseTargets = @(
    @{ Root = $moduleRoot; Name = 'PwshProfile.AzureImages'; Changed = $changed; Notes = @(
            "- Refresh the image catalogue: $($catalog.Images.Count) entries across $($catalog.Locations -join ', ')."
            "- Refresh location completion: $($catalog.AvailableLocations.Count) physical regions reported by Azure."
            "- Refresh support lifecycle dates: $($catalog.Lifecycles.Count) OS cycles."
            '- Live discovery remains the authority for regional availability.'
        )
    }
    @{ Root = $computeRoot; Name = 'PwshProfile.AzureCompute'; Changed = $computeChanged; Notes = @(
            "- Refresh location completion: $($catalog.AvailableLocations.Count) physical regions reported by Azure."
        )
    }
)
foreach ($target in $releaseTargets) {
    if (-not $PrepareRelease -or -not $target.Changed) { continue }
    $manifestPath = Join-Path $target.Root "$($target.Name).psd1"
    $changelogPath = Join-Path $target.Root 'CHANGELOG.md'
    $manifest = [IO.File]::ReadAllText($manifestPath)
    $changelog = [IO.File]::ReadAllText($changelogPath)
    $versionPattern = "(?m)^(\s*ModuleVersion\s*=\s*)'(?<version>\d+\.\d+\.\d+)'"
    $matches = [regex]::Matches($manifest, $versionPattern)
    if ($matches.Count -ne 1) { throw 'Expected one module version assignment.' }
    $version = [version]$matches[0].Groups['version'].Value
    $nextVersion = '{0}.{1}.{2}' -f $version.Major, $version.Minor, ($version.Build + 1)
    if ($changelog -match "(?m)^## \[$([regex]::Escape($nextVersion))\]") { throw "Changelog already contains $nextVersion." }
    $heading = [regex]::Match($changelog, '(?m)^## \[')
    if (-not $heading.Success) { throw 'No version heading in the module changelog.' }
    $newline = if ($changelog.Contains("`r`n")) { "`r`n" } else { "`n" }
    $notes = (@(
            "## [$nextVersion] - $([DateTime]::UtcNow.ToString('yyyy-MM-dd'))"
            ''
        ) + $target.Notes + @('', '')) -join $newline
    $writes[$manifestPath] = [regex]::Replace($manifest, $versionPattern, [Text.RegularExpressions.MatchEvaluator] { param($match) $match.Groups[1].Value + "'$nextVersion'" })
    $writes[$changelogPath] = $changelog.Insert($heading.Index, $notes)
}

$utf8 = [Text.UTF8Encoding]::new($false)
foreach ($entry in $writes.GetEnumerator()) {
    if ([IO.File]::ReadAllText($entry.Key) -ceq $entry.Value) { continue }
    $temporary = "$($entry.Key).$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText($temporary, $entry.Value, $utf8)
        [IO.File]::Replace($temporary, $entry.Key, "$temporary.bak")
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
        if (Test-Path -LiteralPath "$temporary.bak") { Remove-Item -LiteralPath "$temporary.bak" -Force }
    }
}
Write-Host "Catalogue contains $($catalog.Images.Count) image entries. Semantic change: $changed."
