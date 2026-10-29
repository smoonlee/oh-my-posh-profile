param (
    [ValidateSet('Images', 'Compute', 'All')]
    [string] $Module = 'All'
)

$ErrorActionPreference = 'Stop'

function Assert-Discovery {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) { throw $Message }
}

function Assert-DiscoveryThrows {
    param([scriptblock] $Action, [string] $Pattern)
    try { & $Action }
    catch {
        if ($_.Exception.Message -like $Pattern) { return }
        throw
    }
    throw "Expected failure matching '$Pattern'."
}

$global:AzureDiscoveryTestState = @{
    Output     = '[]'
    ExitCode   = 0
    PriceCalls = 0
    Calls      = [System.Collections.Generic.List[object]]::new()
}
function global:az {
    $global:AzureDiscoveryTestState.Calls.Add(@($args))
    $global:LASTEXITCODE = $global:AzureDiscoveryTestState.ExitCode
    if ($args[2] -eq 'show' -and $args[0] -eq 'vm') {
        $urn = $args[[array]::IndexOf($args, '--urn') + 1]
        if ($global:AzureDiscoveryTestState.MetadataErrors -and $global:AzureDiscoveryTestState.MetadataErrors.ContainsKey($urn)) {
            $global:LASTEXITCODE = 1
            $global:AzureDiscoveryTestState.MetadataErrors[$urn]
            return
        }
        if ($global:AzureDiscoveryTestState.ImageMetadata -and $global:AzureDiscoveryTestState.ImageMetadata.ContainsKey($urn)) {
            $global:AzureDiscoveryTestState.ImageMetadata[$urn]
        } else {
            '[{"architecture":"x64","hyperVGeneration":"V2"}]'
        }
        return
    }
    if ($global:AzureDiscoveryTestState.CatalogPublishers) {
        if ($args[0] -eq 'account' -and $args[1] -eq 'list-locations') {
            if ($global:AzureDiscoveryTestState.CatalogRegions) { $global:AzureDiscoveryTestState.CatalogRegions }
            else { '["eastus","uksouth"]' }
            return
        }
        if ($args[0] -eq 'cloud') {
            ConvertTo-Json -InputObject @($global:AzureDiscoveryTestState.CloudName)
            return
        }
        if ($args[2] -eq 'list-publishers') {
            $global:AzureDiscoveryTestState.CatalogPublishers
            return
        }
        if ($global:AzureDiscoveryTestState.FailCatalog -and $args[2] -eq 'list-skus') {
            $global:LASTEXITCODE = 1
            'Simulated catalogue query failure'
            return
        }
    }
    if ($global:AzureDiscoveryTestState.ImageOffers) {
        if ($args[2] -eq 'list-offers') {
            ConvertTo-Json -InputObject @($global:AzureDiscoveryTestState.ImageOffers.Keys | ForEach-Object { @{ name = $_ } })
            return
        }
        $offerName = $args[[array]::IndexOf($args, '--offer') + 1]
        $global:AzureDiscoveryTestState.ImageOffers[$offerName]
        return
    }
    $global:AzureDiscoveryTestState.Output
}

function global:Invoke-RestMethod {
    [CmdletBinding()]
    param([uri] $Uri, [hashtable] $Headers, [int] $TimeoutSec)
    if ($Uri.Host -eq 'prices.azure.com') {
        $global:AzureDiscoveryTestState.PriceCalls++
        if ($global:AzureDiscoveryTestState.FailPrices) { throw 'Simulated pricing outage' }
        $pageIndex = if ($Uri.Query -match 'page=2') { 1 } else { 0 }
        return $global:AzureDiscoveryTestState.PricePages[$pageIndex]
    }
    $global:AzureDiscoveryTestState.LifecycleCalls++
    if ($global:AzureDiscoveryTestState.FailLifecycle) { throw 'Simulated lifecycle outage' }
    if ($Uri.Host -eq 'www.flatcar.org') {
        if ($global:AzureDiscoveryTestState.FlatcarResponse) { return $global:AzureDiscoveryTestState.FlatcarResponse }
        return [pscustomobject]@{ current = [pscustomobject]@{ channel = 'stable'; release_date = '2020-01-01 12:00:00 +0000' } }
    }
    $product = [IO.Path]::GetFileNameWithoutExtension($Uri.AbsolutePath)
    if ($global:AzureDiscoveryTestState.LifecycleResponses.ContainsKey($product)) {
        return , $global:AzureDiscoveryTestState.LifecycleResponses[$product]
    }
    return , @([pscustomobject]@{ cycle = 'test'; releaseDate = '2000-01-01'; eol = '2999-01-01' })
}

try {
    if ($Module -in @('Images', 'All')) {
        $manifest = Join-Path $PSScriptRoot '../src/modules/PwshProfile.AzureImages/PwshProfile.AzureImages.psd1'
        $null = Test-ModuleManifest -Path $manifest
        Import-Module $manifest -Force
        $imageModule = Get-Module PwshProfile.AzureImages
        $global:AzureDiscoveryTestState.LifecycleCalls = 0
        $global:AzureDiscoveryTestState.LifecycleResponses = @{
            windows = @(
                [pscustomobject]@{ cycle = '11-23h2-w'; releaseDate = '2000-01-01'; eol = '2001-01-01'; extendedSupport = '2999-01-01' }
                [pscustomobject]@{ cycle = '11-23h2-e'; releaseDate = '2000-01-01'; eol = '2999-01-01' }
                [pscustomobject]@{ cycle = '11-99h2-w'; releaseDate = '2998-01-01'; eol = '2999-01-01' }
                [pscustomobject]@{ cycle = '10-22h2'; releaseDate = '2000-01-01'; eol = '2001-01-01'; extendedSupport = '2999-01-01' }
                [pscustomobject]@{ cycle = '10-21h2-e-lts'; releaseDate = '2000-01-01'; eol = '2999-01-01' }
            )
        }
        $global:AzureDiscoveryTestState.ImageOffers = [ordered]@{
            'Windows-10' = '[{"name":"22h2-pro"},{"name":"win10-21h2-ent-ltsc"}]'
            'windows-11' = '[{"name":"win11-23h2-pro"},{"name":"win11-23h2-ent"},{"name":"win11-99h2-pro"},{"name":"win11-23h2-ent-preview"},{"name":"unknown"}]'
        }
        $global:AzureDiscoveryTestState.ImageMetadata = @{
            'MicrosoftWindowsDesktop:Windows-10:win10-21h2-ent-ltsc:latest' = '[{"architecture":"x64","hyperVGeneration":"V1"}]'
            'MicrosoftWindowsDesktop:windows-11:win11-23h2-ent:latest'      = '[{"architecture":"Arm64","hyperVGeneration":"V2"}]'
        }
        $supported = @(Get-AzureVmImage westeurope -OS WindowsClient)
        Assert-Discovery ($supported.Count -eq 2 -and $supported.Sku -contains 'win11-23h2-ent' -and $supported.Sku -contains 'win10-21h2-ent-ltsc') 'Default filtering must respect edition/LTSC dates and exclude EOL, paid extensions, future, preview and unknown images.'
        Assert-Discovery ($supported[0].Architecture -eq 'amd64' -and $supported[0].Generation -eq 'Gen1' -and $supported[1].Architecture -eq 'arm64' -and $supported[1].Generation -eq 'Gen2') 'Plain queries must populate verified architecture and generation.'
        Assert-Discovery (@($global:AzureDiscoveryTestState.Calls | Where-Object { $_[2] -eq 'show' }).Count -eq 2) 'Unsupported images must be filtered before metadata requests.'
        $armSupported = @(Get-AzureVmImage westeurope -OS WindowsClient -Arch arm -Generation Gen2)
        Assert-Discovery ($armSupported.Count -eq 1 -and $armSupported[0].Sku -eq 'win11-23h2-ent') 'ARM/Gen2 filters must work with lifecycle filtering enabled.'
        $amdSupported = @(Get-AzureVmImage westeurope -OS WindowsClient -Arch amd64 -Generation Gen1)
        Assert-Discovery ($amdSupported.Count -eq 1 -and $amdSupported[0].Sku -eq 'win10-21h2-ent-ltsc') 'AMD64/Gen1 filters must work with lifecycle filtering enabled.'
        Assert-Discovery (@(Get-AzureVmImage westeurope -OS WindowsClient -Arch amd64 -Generation Gen2).Count -eq 0) 'Nonmatching platform filters must not leak results.'
        $callsBefore = $global:AzureDiscoveryTestState.Calls.Count
        $quickImages = @(Get-AzureVmImage westeurope -OS WindowsClient -IncludeMetadata:$false)
        Assert-Discovery ($quickImages.Count -eq 2 -and @($quickImages | Where-Object { $_.Architecture -ne 'Unknown' -or $_.Generation -ne 'Unknown' }).Count -eq 0) 'Explicit metadata opt-out must preserve name-only results.'
        Assert-Discovery (@($global:AzureDiscoveryTestState.Calls | Select-Object -Skip $callsBefore | Where-Object { $_[2] -eq 'show' }).Count -eq 0) 'Explicit metadata opt-out must avoid details requests.'
        Assert-Discovery (@(Get-AzureVmImage westeurope -OS WindowsClient -IncludeMetadata:$false -Arch x64 -Generation Gen1).Count -eq 1) 'Platform filters must override metadata opt-out.'
        Assert-Discovery ($global:AzureDiscoveryTestState.LifecycleCalls -eq 1) 'Lifecycle data must be fetched once per product, not per SKU.'
        Assert-Discovery (@(Get-AzureVmImage westeurope -OS WindowsClient -Expanded).Count -eq 2) 'Expanded must not bypass lifecycle filtering.'
        Assert-Discovery (@(Get-AzureVmImage westeurope -OS WindowsClient -IncludeUnsupported).Count -eq 7) 'IncludeUnsupported must preserve unfiltered discovery.'
        $savedWindowsOffers = $global:AzureDiscoveryTestState.ImageOffers
        $global:AzureDiscoveryTestState.ImageOffers = [ordered]@{
            'windows-11' = '[{"name":"win11-23h2-avd"},{"name":"win11-23h2-evd"},{"name":"win11-23h2-avd-preview"}]'
            'office-365' = '[{"name":"win11-23h2-avd-m365"},{"name":"win11-23h2-ent-m365"},{"name":"win10-22h2-avd-m365"},{"name":"win11-99h2-avd-m365"},{"name":"23h2-avd-m365"}]'
        }
        $avdImages = @(Get-AzureVmImage westeurope -OS WindowsClient -Arch amd64 -Generation Gen2)
        Assert-Discovery ($avdImages.Count -eq 4 -and $avdImages.Sku -contains 'win11-23h2-avd' -and $avdImages.Sku -contains 'win11-23h2-evd') 'Supported AVD and legacy EVD images must remain discoverable with platform filters.'
        Assert-Discovery ($avdImages.Urn -contains 'MicrosoftWindowsDesktop:office-365:win11-23h2-avd-m365:latest' -and $avdImages.Sku -contains 'win11-23h2-ent-m365') 'WindowsClient must include supported Microsoft 365 images under the office-365 offer.'
        Assert-Discovery (@(Get-AzureVmImage westeurope -OS WindowsClient -Search avd).Count -eq 2) 'AVD search must span Windows and Office offers while excluding expired, preview and unclassified images.'
        Assert-Discovery (@(Get-AzureVmImage westeurope -OS WindowsClient -Expanded).Count -eq 4) 'Expanded must preserve AVD lifecycle filtering.'
        Assert-Discovery (@(Get-AzureVmImage westeurope -OS WindowsClient -IncludeUnsupported).Count -eq 8) 'AVD lifecycle bypass must retain excluded candidates from both offers.'
        $global:AzureDiscoveryTestState.ImageOffers = $savedWindowsOffers
        $bundled = & $imageModule { $script:AzureImagesCatalog }
        $savedImages = $bundled.Images
        $hadLifecycles = [bool]$bundled.PSObject.Properties['Lifecycles']
        $savedLifecycles = $bundled.Lifecycles
        $bundled.Images = @($avdImages | Select-Object *, @{ Name = 'OS'; Expression = { 'WindowsClient' } })
        $bundled | Add-Member -NotePropertyName Lifecycles -NotePropertyValue @(& $imageModule { Get-AzureImageLifecycleData windows }) -Force
        $global:AzureDiscoveryTestState.FailLifecycle = $true
        Assert-Discovery (@(Get-AzureVmImage -Catalog -OS WindowsClient -Arch amd64 -Generation Gen2).Count -eq 4) 'Offline AVD and Microsoft 365 images must use bundled lifecycle and platform data.'
        $bundled.Images = @($supported | Select-Object *, @{ Name = 'OS'; Expression = { 'WindowsClient' } })
        Assert-Discovery (@(Get-AzureVmImage -Catalog -OS WindowsClient).Count -eq 2) 'Offline supported-only discovery must use bundled lifecycle dates without HTTP.'
        Assert-Discovery (@(Get-AzureVmImage -Catalog -OS WindowsClient -Arch arm64 -Generation Gen2).Count -eq 1) 'Offline platform filters must work alongside lifecycle checks.'
        & $imageModule {
            $script:AzureImagesCatalog.Lifecycles = @([pscustomobject]@{ Product = 'windows'; Cycle = '11-23h2-e'; ReleaseDate = '2023-10-31'; Eol = '2026-11-10' })
            if (-not (Test-AzureImageSupported MicrosoftWindowsDesktop windows-11 win11-23h2-ent -Catalog -CurrentDate '2026-11-10')) { throw 'Last support day must remain supported.' }
            if (Test-AzureImageSupported MicrosoftWindowsDesktop windows-11 win11-23h2-ent -Catalog -CurrentDate '2026-11-11') { throw 'Support must expire without a catalogue refresh.' }
            $script:AzureImageLifecycleCache.Clear()
        }
        Assert-DiscoveryThrows { Get-AzureVmImage westeurope -OS WindowsClient } '*Unable to retrieve lifecycle data*'
        Assert-Discovery (@(Get-AzureVmImage westeurope -OS WindowsClient -IncludeUnsupported).Count -eq 7) 'IncludeUnsupported must work during a lifecycle service outage.'
        $global:AzureDiscoveryTestState.Remove('FailLifecycle')
        $global:AzureDiscoveryTestState.LifecycleResponses.windows = @([pscustomobject]@{ cycle = 'bad'; releaseDate = '2000-01-01'; eol = $null })
        Assert-DiscoveryThrows { Get-AzureVmImage westeurope -OS WindowsClient } '*Invalid lifecycle end-of-life date*'
        $global:AzureDiscoveryTestState.LifecycleResponses.Remove('windows')
        $global:AzureDiscoveryTestState.LifecycleResponses.ubuntu = @(
            [pscustomobject]@{ cycle = '18.04'; releaseDate = '2000-01-01'; eol = '2001-01-01'; extendedSupport = '2999-01-01' }
            [pscustomobject]@{ cycle = '22.04'; releaseDate = '2000-01-01'; eol = '2999-01-01' }
        )
        $global:AzureDiscoveryTestState.ImageOffers = [ordered]@{
            'ubuntu-18_04-lts'             = '[{"name":"server"}]'
            '0001-com-ubuntu-server-jammy' = '[{"name":"22_04-lts-gen2"}]'
            'ubuntu-pro-18_04-lts'         = '[{"name":"server"}]'
        }
        Assert-Discovery (@(Get-AzureVmImage uksouth -OS Ubuntu -Expanded).Count -eq 1) 'Expanded must not treat paid Ubuntu extended support as normal security support.'
        Assert-Discovery (@(Get-AzureVmImage uksouth -OS Ubuntu -IncludeUnsupported).Count -eq 2) 'Lifecycle bypass must not bypass standard-variant filtering.'
        Assert-Discovery (@(Get-AzureVmImage uksouth -OS Ubuntu -Expanded -IncludeUnsupported).Count -eq 3) 'Both opt-ins must retain all image variants and lifecycles.'
        $global:AzureDiscoveryTestState.LifecycleResponses.Remove('ubuntu')
        & $imageModule {
            foreach ($mapping in @(
                    , @('MicrosoftWindowsServer', 'WindowsServer', '2022-datacenter', 'windows-server', '2022')
                    , @('MicrosoftWindowsDesktop', 'windows-11', 'win11-24h2-entn', 'windows', '11-24h2-e')
                    , @('MicrosoftWindowsDesktop', 'windows-11', 'win11-24h2-avd', 'windows', '11-24h2-e')
                    , @('MicrosoftWindowsDesktop', 'windows-11', 'win11-23h2-evd', 'windows', '11-23h2-e')
                    , @('MicrosoftWindowsDesktop', 'office-365', 'win11-24h2-avd-m365', 'windows', '11-24h2-e')
                    , @('MicrosoftWindowsDesktop', 'office-365', 'win11-23h2-evd', 'windows', '11-23h2-e')
                    , @('MicrosoftWindowsDesktop', 'office-365', 'win10-22h2-avd-m365', 'windows', '10-22h2')
                    , @('MicrosoftWindowsDesktop', 'Windows-10', 'win10-2019-ent-ltsc', 'windows', '10-1809-e-lts')
                    , @('Debian', 'debian-13', '13-gen2', 'debian', '13')
                    , @('RedHat', 'RHEL', '9_6-gen2', 'rhel', '9')
                    , @('SUSE', 'sles-15-sp7', 'gen2', 'sles', '15.7')
                    , @('SUSE', 'sles-16-0-x86-64', 'gen1', 'sles', '16.0')
                    , @('SUSE', 'sles-16-0-arm64', 'gen2', 'sles', '16.0')
                    , @('ciq', 'rocky-community-editions', 'rocky-community-10-arm', 'rocky-linux', '10')
                    , @('ciq', 'rocky-community-editions', 'rocky-community-9', 'rocky-linux', '9')
                    , @('Oracle', 'Oracle-Linux', '9_6', 'oracle-linux', '9')
                    , @('resf', 'rockylinux-x86_64', '9-base', 'rocky-linux', '9')
                    , @('resf', 'rockylinux-9', 'base', 'rocky-linux', '9')
                    , @('almalinux', 'almalinux', '9-gen2', 'almalinux', '9')
                    , @('FreeBSD', 'freebsd-14_4', 'release', 'freebsd', '14.4')
                )) {
                $reference = Get-AzureImageLifecycleReference $mapping[0] $mapping[1] $mapping[2]
                if ($reference.Product -ne $mapping[3] -or $reference.Cycle -ne $mapping[4]) {
                    if ($reference -or $mapping[3]) { throw "Incorrect lifecycle mapping: $($mapping -join '/')" }
                }
            }
            if (Get-AzureImageLifecycleReference RedHat RHEL '8_6-eus') { throw 'EUS-specific images must not be classified as normal support.' }
        }
        $bundled.Images = $savedImages
        if ($hadLifecycles) { $bundled.Lifecycles = $savedLifecycles } else { $bundled.PSObject.Properties.Remove('Lifecycles') }
        $global:AzureDiscoveryTestState.Remove('ImageOffers')
        $global:AzureDiscoveryTestState.Remove('ImageMetadata')
        Assert-Discovery (& $imageModule { Test-AzureImageSupported kinvolk flatcar-container-linux-free stable-gen2 }) 'Flatcar stable must use the official production channel feed.'
        foreach ($channel in @('alpha', 'beta', 'lts2022', 'unknown')) {
            Assert-Discovery (-not (& $imageModule { param($sku) Test-AzureImageSupported kinvolk flatcar-container-linux-free $sku } $channel)) 'Unverified Flatcar channels must remain excluded.'
        }
        $global:AzureDiscoveryTestState.FlatcarResponse = [pscustomobject]@{ current = [pscustomobject]@{ channel = 'beta'; release_date = '2020-01-01' } }
        & $imageModule { $script:AzureImageLifecycleCache.Remove('flatcar') }
        Assert-DiscoveryThrows { & $imageModule { Get-AzureImageLifecycleData flatcar } } '*Invalid Flatcar stable channel*'
        $global:AzureDiscoveryTestState.FlatcarResponse = $null
        'PASS: supported-only defaults, editions, LTSC, expiry, caching, offline data and failure handling.'
        $PSDefaultParameterValues = @{ 'Get-AzureVmImage:IncludeUnsupported' = $true; 'Get-AzureVmImage:IncludeMetadata' = $false }
        $global:AzureDiscoveryTestState.Output = '[{"name":"2022-datacenter"},{"name":"2025-datacenter-core"},{"name":"2025-datacenter"}]'
        $images = @(Get-AzureVmImage -Location uksouth -OS WindowsServer -Search 2025 -Subscription test-sub)
        Assert-Discovery ($images.Count -eq 2) 'Expected two Windows Server 2025 SKUs.'
        Assert-Discovery ($images[0].Urn -eq 'MicrosoftWindowsServer:WindowsServer:2025-datacenter:latest') 'Incorrect image URN.'
        Assert-Discovery ($images[0].Location -eq 'uksouth') 'Image region lost.'
        $longImage = [pscustomobject]@{
            PSTypeName = 'PwshProfile.AzureVmImage'; Publisher = 'Canonical'; Location = 'uksouth'; Source = 'Live'
            Offer = '0001-com-ubuntu-pro-minimal-cis-jammy'; Sku = 'pro-cis-minimal-22_04-lts-gen2-arm64-tail'; Version = 'latest'
        }
        foreach ($width in @(80, 120, 160)) {
            $rendered = $longImage | Out-String -Width $width
            Assert-Discovery ($rendered -notmatch '\.\.\.|\u2026' -and $rendered -match 'tail') "Image table truncated SKU text at width $width."
            Assert-Discovery ($rendered -match 'Canonical' -and $rendered -match 'uksouth' -and $rendered -match 'Live') 'Image grouping lost publisher, region or source.'
            Assert-Discovery ($rendered.Contains($longImage.Offer) -and $rendered.Contains($longImage.Sku)) "Offer and SKU names should fit without splitting at width $width."
        }
        $longServerImage = [pscustomobject]@{
            PSTypeName = 'PwshProfile.AzureVmImage'; Publisher = 'MicrosoftWindowsServer'; Location = 'westeurope'; Source = 'Live'
            Offer = 'WindowsServer'; Sku = '2019-datacenter-core-with-containers-smalldisk-g2'; Version = 'latest'; Architecture = 'amd64'; Generation = 'Gen2'
        }
        foreach ($width in @(80, 120, 160)) {
            $rendered = $longServerImage | Out-String -Width $width
            Assert-Discovery ($rendered.Contains($longServerImage.Sku)) "Long Windows Server SKU should use the available row width at $width columns."
            Assert-Discovery ($rendered -match 'MicrosoftWindowsServer \| WindowsServer \| westeurope \| Live') 'Offer must remain visible in the image group heading.'
        }
        $longServerImage.Sku = '2019-datacenter-core-with-containers-smalldisk-g2-extra-long-sku-ending'
        foreach ($width in @(80, 120)) {
            $rendered = $longServerImage | Out-String -Width $width
            Assert-Discovery ($rendered -notmatch '\.\.\.|\u2026' -and $rendered -match 'ending') "Extra-long SKU must wrap without truncation at width $width."
            if ($width -eq 120) { Assert-Discovery ($rendered.Contains($longServerImage.Sku)) 'Wide terminals must show extra-long SKUs on one line.' }
        }
        $shortFirstImage = $longServerImage.PSObject.Copy()
        $shortFirstImage.Sku = 'short'
        $fullWidthImage = $longServerImage.PSObject.Copy()
        $fullWidthImage.Sku = 'x' * 200
        foreach ($width in @(60, 80, 120, 160)) {
            $lines = @(@($shortFirstImage, $fullWidthImage) | ForEach-Object { $_ } | Out-String -Width $width -Stream)
            $header = @($lines | Where-Object { $_ -match '^Arch\s+Gen\s+Version\s+SKU' })
            $fullWidthRow = @($lines | Where-Object { $_ -match '^amd64\s+Gen2\s+latest\s+x' })
            Assert-Discovery ($header.Count -eq 1 -and $header[0].IndexOf('SKU') -eq 31) "Metadata columns must retain their widths at $width columns."
            Assert-Discovery ($fullWidthRow.Count -eq 1 -and $fullWidthRow[0].Length -eq $width) "A short first SKU must not prevent later rows filling all $width columns."
            $skuFragments = @($lines | Where-Object { $_ -match '^amd64\s+Gen2\s+latest\s+x|^ {31}x' } | ForEach-Object { $_.Substring(31).TrimEnd() })
            Assert-Discovery (($skuFragments -join '') -eq $fullWidthImage.Sku) "Full-width wrapping must retain the complete SKU at $width columns."
        }
        $call = $global:AzureDiscoveryTestState.Calls[-1]
        Assert-Discovery ($call -contains 'list-skus' -and $call -notcontains '--all') 'Name-only query must list SKUs, not every version.'
        Assert-Discovery ($call[$call.IndexOf('--subscription') + 1] -eq 'test-sub') 'Subscription not forwarded.'
        Assert-Discovery ($call -contains '--only-show-errors' -and $call -contains 'json') 'CLI output options missing.'
        $bicep = $images[0] | ConvertTo-AzureVmImageBicep
        Assert-Discovery ($bicep -eq "imageReference: {`n  publisher: 'MicrosoftWindowsServer'`n  offer: 'WindowsServer'`n  sku: '2025-datacenter'`n  version: 'latest'`n}") 'Incorrect Bicep output.'
        Assert-Discovery (@(Get-AzureVmImage uksouth -Search '[2025]').Count -eq 0) 'Search must be literal, not a wildcard.'
        Assert-Discovery (@(Get-AzureVmImage uksouth -Sku '*core').Count -eq 1) 'SKU wildcard failed.'
        $global:AzureDiscoveryTestState.ImageOffers = [ordered]@{
            '0001-com-ubuntu-server-jammy' = '[{"name":"22_04-lts-gen2"}]'
            'ubuntu-24_04-lts'             = '[{"name":"server"}]'
            'ubuntu-26_04-lts'             = '[{"name":"server"},{"name":"server-arm64"}]'
            'unrelated-product'            = '[{"name":"not-ubuntu"}]'
        }
        $callCount = $global:AzureDiscoveryTestState.Calls.Count
        $ubuntu = @(Get-AzureVmImage uksouth -OS Ubuntu -Subscription test-sub)
        Assert-Discovery ($ubuntu.Count -eq 4) 'Ubuntu discovery must include all Ubuntu offers, not just 24.04.'
        Assert-Discovery ($ubuntu.Urn -contains 'Canonical:ubuntu-26_04-lts:server:latest') 'Ubuntu 26.04 offer or URN lost.'
        Assert-Discovery ($ubuntu.Urn -contains 'Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest') 'Legacy Ubuntu 22.04 offer lost.'
        foreach ($call in @($global:AzureDiscoveryTestState.Calls | Select-Object -Skip $callCount)) {
            Assert-Discovery ($call -contains 'Canonical' -and $call -contains 'test-sub' -and $call -contains 'uksouth') 'Ubuntu queries must retain publisher, subscription and region.'
            Assert-Discovery ($call -notcontains '--all' -and $call -notcontains 'unrelated-product') 'Ubuntu SKU discovery queried versions or an unrelated offer.'
        }
        Assert-Discovery ($global:AzureDiscoveryTestState.Calls[$callCount][2] -eq 'list-offers') 'Ubuntu discovery must start with live offers.'
        Assert-Discovery (@(Get-AzureVmImage uksouth -OS Ubuntu -Search 22.04).Count -eq 1) 'Dotted release search must match legacy SKU names.'
        Assert-Discovery (@(Get-AzureVmImage uksouth -OS Ubuntu -Search 26.04).Count -eq 2) 'Release search must match modern offer names.'
        Assert-Discovery (@(Get-AzureVmImage uksouth -OS Ubuntu -Sku '*arm64').Count -eq 1) 'Ubuntu SKU wildcard filtering failed.'
        Assert-Discovery (@(Get-AzureVmImage uksouth -OS Ubuntu -Search '[26.04]').Count -eq 0) 'Ubuntu search must remain literal.'
        Assert-Discovery (@(Get-AzureVmImage uksouth -Publisher Canonical).Count -eq 5) 'Publisher discovery must include all offers without requiring a preset.'
        Assert-Discovery (@(Get-AzureVmImage uksouth -Publisher Canonical -Offer 'ubuntu-26*').Count -eq 2) 'Custom offer wildcard filtering failed.'
        $callCount = $global:AzureDiscoveryTestState.Calls.Count
        $ubuntu = @(Get-AzureVmImage uksouth -Publisher Canonical -Offer ubuntu-26_04-lts)
        Assert-Discovery ($ubuntu.Count -eq 2 -and $global:AzureDiscoveryTestState.Calls.Count -eq $callCount + 1) 'Explicit Ubuntu offer must bypass offer discovery.'
        Assert-Discovery (($ubuntu[0] | ConvertTo-AzureVmImageBicep) -like "*offer: 'ubuntu-26_04-lts'*") 'Ubuntu offer lost in Bicep.'
        $global:AzureDiscoveryTestState.ImageOffers = [ordered]@{
            'ubuntu-24_04-lts' = '[{"publisher":"Canonical","offer":"ubuntu-24_04-lts","sku":"server","version":"24.4.1"}]'
            'ubuntu-26_04-lts' = '[{"publisher":"Canonical","offer":"ubuntu-26_04-lts","sku":"server","version":"26.4.9"},{"publisher":"Canonical","offer":"ubuntu-26_04-lts","sku":"server","version":"26.4.10"},{"publisher":"Canonical","offer":"ubuntu-24_04-lts","sku":"server","version":"24.4.1"},{"publisher":"Canonical","offer":"ubuntu-26_04-lts","sku":"server-arm64","version":"26.4.11"}]'
        }
        $versions = @(Get-AzureVmImage uksouth -OS Ubuntu -Sku server -ListVersions)
        Assert-Discovery ($versions.Count -eq 3) 'Ubuntu versions must preserve shared SKUs across offers and reject partial matches.'
        Assert-Discovery ($versions[1].Urn -eq 'Canonical:ubuntu-26_04-lts:server:26.4.10') 'Ubuntu versions must be sorted within each offer and retain its URN.'
        $global:AzureDiscoveryTestState.ImageOffers = [ordered]@{ 'unrelated-product' = '[]' }
        $callCount = $global:AzureDiscoveryTestState.Calls.Count
        Assert-Discovery (@(Get-AzureVmImage uksouth -OS Ubuntu).Count -eq 0) 'No Ubuntu offers should emit no images.'
        Assert-Discovery ($global:AzureDiscoveryTestState.Calls.Count -eq $callCount + 1) 'No Ubuntu offers should skip SKU queries.'
        $global:AzureDiscoveryTestState.ImageOffers = [ordered]@{
            'ubuntu-26_04-lts'                      = '[{"name":"opaque-a"},{"name":"opaque-b"},{"name":"legacy"},{"name":"minimal"},{"name":"server-cis"}]'
            '0001-com-ubuntu-pro-microsoft'         = '[{"name":"server"}]'
            '0001-com-ubuntu-pro-minimal-cis-jammy' = '[{"name":"server"}]'
        }
        $callCount = $global:AzureDiscoveryTestState.Calls.Count
        Assert-Discovery (@(Get-AzureVmImage uksouth -OS Ubuntu).Count -eq 3) 'Default discovery must hide specialised offers and SKUs.'
        $standardCalls = @($global:AzureDiscoveryTestState.Calls | Select-Object -Skip $callCount)
        Assert-Discovery ($standardCalls.Count -eq 2) 'Default discovery must skip specialised offers before querying their SKUs.'
        Assert-Discovery (@(Get-AzureVmImage uksouth -OS Ubuntu -Expanded).Count -eq 7) 'Expanded discovery must retain Pro, CIS and minimal variants.'
        $global:AzureDiscoveryTestState.ImageMetadata = @{
            'Canonical:ubuntu-26_04-lts:opaque-a:latest' = '[{"architecture":"Arm64","hyperVGeneration":"V2"}]'
            'Canonical:ubuntu-26_04-lts:opaque-b:latest' = '[{"architecture":"x64","hyperVGeneration":"V2"}]'
            'Canonical:ubuntu-26_04-lts:legacy:latest'   = '[{"architecture":"x64","hyperVGeneration":"V1"}]'
        }
        $armImages = @(Get-AzureVmImage uksouth -OS Ubuntu -Arch arm -Generation Gen2 -Subscription test-sub)
        Assert-Discovery ($armImages.Count -eq 1 -and $armImages[0].Sku -eq 'opaque-a' -and $armImages[0].Architecture -eq 'arm64') 'Architecture must come from Azure metadata, not SKU spelling.'
        $metadataCall = $global:AzureDiscoveryTestState.Calls[-1]
        Assert-Discovery ($metadataCall -contains 'test-sub' -and $metadataCall -contains 'uksouth' -and $metadataCall -contains '[@]') 'Metadata query lost region, subscription or array projection.'
        $amdImages = @(Get-AzureVmImage uksouth -OS Ubuntu -Arch amd64 -Generation Gen1)
        Assert-Discovery ($amdImages.Count -eq 1 -and $amdImages[0].Sku -eq 'legacy') 'Gen1/amd64 filtering failed.'
        Assert-Discovery (@(Get-AzureVmImage uksouth -OS Ubuntu -Arch x64).Count -eq 2) 'x64 architecture alias failed.'
        $global:AzureDiscoveryTestState.ImageMetadata['Canonical:ubuntu-26_04-lts:opaque-a:latest'] = '[{}]'
        Assert-Discovery (@(Get-AzureVmImage uksouth -OS Ubuntu -Arch arm64).Count -eq 0) 'Unknown metadata must not be inferred from SKU names.'
        Assert-DiscoveryThrows { Get-AzureVmImage uksouth -Generation arm } '*Gen1*Gen2*'
        $global:AzureDiscoveryTestState.Remove('ImageMetadata')
        $global:AzureDiscoveryTestState.ImageOffers = [ordered]@{
            'Windows-10' = '[{"name":"19h1-ent"}]'
            'windows-11' = '[{"name":"win11-24h2-pro"}]'
        }
        $unresolvedError = "ERROR: Can't resolve the version of 'MicrosoftWindowsDesktop:Windows-10:19h1-ent'"
        $unresolvedUrn = 'MicrosoftWindowsDesktop:Windows-10:19h1-ent:latest'
        $global:AzureDiscoveryTestState.MetadataErrors = @{ $unresolvedUrn = $unresolvedError }
        foreach ($metadataOptions in @(@{ IncludeMetadata = $true }, @{ Arch = 'amd64' }, @{ Generation = 'Gen2' })) {
            $lookupWarnings = @()
            $availableImages = @(Get-AzureVmImage westeurope -OS WindowsClient @metadataOptions -WarningVariable lookupWarnings -WarningAction SilentlyContinue)
            Assert-Discovery ($availableImages.Count -eq 1 -and $availableImages[0].Sku -eq 'win11-24h2-pro' -and $availableImages[0].Architecture -eq 'amd64') 'An unresolved latest SKU must not stop subsequent offers or emit an unverified image.'
            Assert-Discovery ($lookupWarnings.Count -eq 1 -and $lookupWarnings[0] -like "*$unresolvedUrn*westeurope*") 'Skipped image warning must identify its URN and region.'
        }
        Assert-Discovery (@(Get-AzureVmImage westeurope -OS WindowsClient).Count -eq 2) 'Quick discovery must not resolve latest versions.'
        foreach ($metadataError in @('ERROR: Please run az login', 'ERROR: AuthorizationFailed', 'ERROR: Connection timed out', "ERROR: Can't resolve the version of 'Other:Offer:Sku'")) {
            $global:AzureDiscoveryTestState.MetadataErrors[$unresolvedUrn] = $metadataError
            Assert-DiscoveryThrows { Get-AzureVmImage westeurope -OS WindowsClient -IncludeMetadata } "*$metadataError*"
        }
        $global:AzureDiscoveryTestState.ImageOffers['Windows-10'] = '[{"publisher":"MicrosoftWindowsDesktop","offer":"Windows-10","sku":"19h1-ent","version":"1.0.0"}]'
        $global:AzureDiscoveryTestState.MetadataErrors['MicrosoftWindowsDesktop:Windows-10:19h1-ent:1.0.0'] = $unresolvedError
        Assert-DiscoveryThrows { Get-AzureVmImage westeurope -Publisher MicrosoftWindowsDesktop -Offer Windows-10 -Sku 19h1-ent -ListVersions -IncludeMetadata } "*$unresolvedError*"
        $global:AzureDiscoveryTestState.Remove('MetadataErrors')
        $global:AzureDiscoveryTestState.Remove('ImageOffers')
        $null = Get-AzureVmImage uksouth -Publisher Contoso -Offer Example
        Assert-Discovery ($global:AzureDiscoveryTestState.Calls[-1] -contains 'Contoso') 'Custom publisher not forwarded.'
        Assert-DiscoveryThrows { Get-AzureVmImage uksouth -OS Ubuntu -Publisher Contoso -Offer Example } '*Catalog*'
        $callCount = $global:AzureDiscoveryTestState.Calls.Count
        Assert-DiscoveryThrows { Get-AzureVmImage uksouth -ListVersions } '*exact -Sku*'
        Assert-Discovery ($global:AzureDiscoveryTestState.Calls.Count -eq $callCount) 'Invalid version request reached Azure.'
        $global:AzureDiscoveryTestState.Output = '[{"publisher":"MicrosoftWindowsServer","offer":"WindowsServer","sku":"2025-datacenter","version":"1.0.9"},{"publisher":"MicrosoftWindowsServer","offer":"WindowsServer","sku":"2025-datacenter","version":"1.0.10"},{"publisher":"MicrosoftWindowsServer","offer":"WindowsServer","sku":"2025-datacenter-core","version":"1.0.11"}]'
        $versions = @(Get-AzureVmImage uksouth -Sku '2025-datacenter' -ListVersions)
        Assert-Discovery ($versions.Count -eq 2 -and $versions[0].Version -eq '1.0.10') 'Versions must be numerically sorted and exact-SKU filtered.'
        Assert-Discovery ($global:AzureDiscoveryTestState.Calls[-1] -contains '--all') 'Versions require a live list query.'
        Assert-Discovery (($versions[0] | ConvertTo-AzureVmImageBicep) -like "*version: '1.0.10'*") 'Pinned version lost in Bicep.'
        Assert-DiscoveryThrows { [pscustomobject]@{ Publisher = "bad'value" } | ConvertTo-AzureVmImageBicep } '*Marketplace identifier*'
        $global:AzureDiscoveryTestState.Output = '[]'
        Assert-Discovery (@(Get-AzureVmImage uksouth).Count -eq 0) 'Empty catalogue should emit no objects.'
        $global:AzureDiscoveryTestState.Output = 'not json'
        Assert-DiscoveryThrows { Get-AzureVmImage uksouth } '*invalid JSON*'
        $global:AzureDiscoveryTestState.Output = '{}'
        Assert-DiscoveryThrows { Get-AzureVmImage uksouth } '*invalid JSON*'
        $global:AzureDiscoveryTestState.ExitCode = 1
        $global:AzureDiscoveryTestState.Output = 'Please run az login'
        Assert-DiscoveryThrows { Get-AzureVmImage uksouth } '*image lookup failed*az login*'
        $global:AzureDiscoveryTestState.ExitCode = 0
        $completion = [System.Management.Automation.CommandCompletion]::CompleteInput('Get-AzureVmImage -Location uks', 30, $null)
        Assert-Discovery ($completion.CompletionMatches.CompletionText -contains 'uksouth') 'Image region completion missing.'
        foreach ($region in @('belgiumcentral', 'chilecentral', 'indiasouthcentral', 'newzealandnorth', 'swedencentral')) {
            $inputText = "Get-AzureVmImage -Location $region"
            $completion = [System.Management.Automation.CommandCompletion]::CompleteInput($inputText, $inputText.Length, $null)
            Assert-Discovery ($completion.CompletionMatches.CompletionText -contains $region) "Image region completion missing $region."
        }
        $inputText = 'Get-AzureVmImage -OS Deb'
        $completion = [System.Management.Automation.CommandCompletion]::CompleteInput($inputText, $inputText.Length, $null)
        Assert-Discovery ($completion.CompletionMatches.CompletionText -contains 'Debian') 'Catalogue OS completion missing.'
        $imageModule = Get-Module PwshProfile.AzureImages
        $bundled = & $imageModule { $script:AzureImagesCatalog }
        $sourceCatalog = Get-Content (Join-Path $PSScriptRoot '../AzureImagesCatalog.json') -Raw | ConvertFrom-Json
        Assert-Discovery (($bundled | ConvertTo-Json -Depth 10 -Compress) -eq ($sourceCatalog | ConvertTo-Json -Depth 10 -Compress)) 'Bundled catalogue differs from its source.'
        $global:AzureDiscoveryTestState.ImageOffers = [ordered]@{ 'debian-13' = '[{"name":"13-gen2"}]' }
        $debian = @(Get-AzureVmImage uksouth -OS Debian)
        Assert-Discovery ($debian.Count -eq 1 -and $debian[0].Publisher -eq 'Debian' -and $debian[0].Source -eq 'Live') 'Catalogue-based live OS discovery failed.'
        $global:AzureDiscoveryTestState.CatalogPublishers = '[{"name":"Debian"}]'
        Assert-Discovery (@(Get-AzureVmImage uksouth -OS All -Subscription test-sub).Count -eq 1) 'All OS discovery must skip publishers absent from the region.'
        Assert-Discovery (@(Get-AzureVmImage uksouth -OS AzureLinux).Count -eq 0) 'Unavailable alternative publishers must not be queried.'
        $global:AzureDiscoveryTestState.Remove('CatalogPublishers')
        $global:AzureDiscoveryTestState.Remove('ImageOffers')
        $callCount = $global:AzureDiscoveryTestState.Calls.Count
        Assert-DiscoveryThrows { Get-AzureVmImage uksouth -OS NotAnOS } '*Unknown OS*'
        $savedImages = $bundled.Images
        try {
            & $imageModule { $script:AzureImagesCatalog.Images = @() }
            Assert-DiscoveryThrows { Get-AzureVmImage -Catalog } '*not been populated*'
            & $imageModule {
                $script:AzureImagesCatalog.Images = @(
                    [pscustomobject]@{ OS = 'Ubuntu'; Location = 'uksouth'; Publisher = 'Canonical'; Offer = 'ubuntu-26_04-lts'; Sku = 'server'; Version = 'latest'; Urn = 'Canonical:ubuntu-26_04-lts:server:latest'; Architecture = 'arm64'; Generation = 'Gen2' }
                    [pscustomobject]@{ OS = 'Debian'; Location = 'eastus'; Publisher = 'Debian'; Offer = 'debian-13'; Sku = '13-gen2'; Version = 'latest'; Urn = 'Debian:debian-13:13-gen2:latest'; Architecture = 'amd64'; Generation = 'Gen2' }
                )
            }
            Assert-Discovery (@(Get-AzureVmImage -Catalog).Count -eq 2) 'Offline catalogue must default to all OS families.'
            $cached = @(Get-AzureVmImage -Catalog -Search 26.04)
            Assert-Discovery ($cached.Count -eq 1 -and $cached[0].Source -eq 'Catalog') 'Offline release search or source label failed.'
            Assert-Discovery (@(Get-AzureVmImage -Catalog -OS Debian -Location eastus -Sku '*gen2').Count -eq 1) 'Offline OS, region or SKU filtering failed.'
            Assert-Discovery (@(Get-AzureVmImage -Catalog -Publisher Canonical -Offer 'ubuntu*').Count -eq 1) 'Offline publisher filtering failed.'
            Assert-Discovery (@(Get-AzureVmImage -Catalog -Arch arm -Generation Gen2).Count -eq 1) 'Offline architecture/generation filtering failed.'
            & $imageModule {
                $script:AzureImagesCatalog.Images += [pscustomobject]@{ OS = 'Ubuntu'; Location = 'uksouth'; Publisher = 'Canonical'; Offer = 'ubuntu-pro'; Sku = 'server-cis'; Version = 'latest'; Urn = 'Canonical:ubuntu-pro:server-cis:latest' }
            }
            Assert-Discovery (@(Get-AzureVmImage -Catalog).Count -eq 2 -and @(Get-AzureVmImage -Catalog -Expanded).Count -eq 3) 'Offline standard/expanded filtering differs from live discovery.'
            Assert-Discovery (& $imageModule { Test-AzureImageStandard MicrosoftWindowsDesktop win11 win11-pro }) 'Windows Pro editions must not be confused with Ubuntu Pro.'
            Assert-DiscoveryThrows { Get-AzureVmImage -Catalog -ListVersions } '*parameter set*'
            Assert-Discovery ($global:AzureDiscoveryTestState.Calls.Count -eq $callCount) 'Offline queries or invalid OS selection called Azure.'
        } finally {
            & $imageModule { param($images) $script:AzureImagesCatalog.Images = $images } $savedImages
        }
        $catalogRoot = Join-Path ([IO.Path]::GetTempPath()) ('azure-catalog-' + [guid]::NewGuid().ToString('N'))
        try {
            $tempModuleRoot = Join-Path $catalogRoot 'src/modules/PwshProfile.AzureImages'
            $null = New-Item -ItemType Directory -Path $tempModuleRoot -Force
            foreach ($name in @('PwshProfile.AzureImages.psm1', 'PwshProfile.AzureImages.psd1', 'PwshProfile.AzureImages.Format.ps1xml', 'CHANGELOG.md')) {
                Copy-Item (Join-Path (Split-Path $manifest -Parent) $name) (Join-Path $tempModuleRoot $name)
            }
            $catalogPath = Join-Path $catalogRoot 'AzureImagesCatalog.json'
            $tempComputeRoot = Join-Path $catalogRoot 'src/modules/PwshProfile.AzureCompute'
            $computeSource = Join-Path $PSScriptRoot '../src/modules/PwshProfile.AzureCompute'
            Copy-Item -LiteralPath $computeSource -Destination $tempComputeRoot -Recurse
            $computeVersion = (Import-PowerShellDataFile (Join-Path $tempComputeRoot 'PwshProfile.AzureCompute.psd1')).ModuleVersion
            $fixture = [pscustomobject]@{
                SchemaVersion = 1; Cloud = 'AzureCloud'; Locations = @('uksouth', 'eastus')
                AvailableLocations = @('eastus', 'uksouth')
                Presets = @([pscustomobject]@{ OS = 'Ubuntu'; Publisher = 'Canonical'; Offer = '*ubuntu*' })
                Images = @()
            }
            $fixture | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $catalogPath -Encoding UTF8
            $updater = Join-Path $PSScriptRoot 'Update-AzureImagesCatalog.ps1'
            & $updater -RepositoryRoot $catalogRoot -EmbedOnly
            $global:AzureDiscoveryTestState.CatalogPublishers = '[{"name":"Canonical"}]'
            $global:AzureDiscoveryTestState.CloudName = 'AzureCloud'
            $global:AzureDiscoveryTestState.ImageOffers = [ordered]@{
                'ubuntu-26_04-lts' = '[{"name":"server"},{"name":"server-arm64"}]'
                'ubuntu-pro'       = '[{"name":"server-cis"}]'
            }
            $callCount = $global:AzureDiscoveryTestState.Calls.Count
            & $updater -RepositoryRoot $catalogRoot -Subscription test-sub -PrepareRelease
            $updated = Get-Content $catalogPath -Raw | ConvertFrom-Json
            Assert-Discovery ($updated.Images.Count -eq 6 -and $updated.Images.Offer -contains 'ubuntu-pro') 'Refresh must retain expanded variants in each configured region.'
            Assert-Discovery (@($updated.Images | Where-Object { $_.Architecture -ne 'amd64' -or $_.Generation -ne 'Gen2' }).Count -eq 0) 'Refresh must retain verified image metadata.'
            Assert-Discovery ($updated.Lifecycles.Count -eq 11 -and $updated.Lifecycles.Product -contains 'windows' -and $updated.Lifecycles.Product -contains 'flatcar') 'Refresh must bundle validated support lifecycle data.'
            $regionCall = @($global:AzureDiscoveryTestState.Calls | Select-Object -Skip $callCount | Where-Object { $_[0] -eq 'account' })[0]
            Assert-Discovery ($regionCall -contains 'test-sub') 'Region discovery lost its explicit subscription.'
            foreach ($call in @($global:AzureDiscoveryTestState.Calls | Select-Object -Skip $callCount | Where-Object { $_[0] -eq 'vm' })) {
                Assert-Discovery ($call -contains 'test-sub') 'Catalogue refresh lost its explicit subscription.'
            }
            $updatedManifest = Import-PowerShellDataFile (Join-Path $tempModuleRoot 'PwshProfile.AzureImages.psd1')
            $originalVersion = [version](Import-PowerShellDataFile $manifest).ModuleVersion
            $expectedVersion = '{0}.{1}.{2}' -f $originalVersion.Major, $originalVersion.Minor, ($originalVersion.Build + 1)
            Assert-Discovery ($updatedManifest.ModuleVersion -eq $expectedVersion) 'Catalogue changes must prepare an independent patch release.'
            Assert-Discovery ((Import-PowerShellDataFile (Join-Path $tempComputeRoot 'PwshProfile.AzureCompute.psd1')).ModuleVersion -eq $computeVersion) 'Image-only changes must not bump Compute.'
            $tracked = @($catalogPath) + @(Get-ChildItem $tempModuleRoot, $tempComputeRoot -File | Select-Object -ExpandProperty FullName)
            $hashes = @($tracked | ForEach-Object { (Get-FileHash $_ -Algorithm SHA256).Hash }) -join ','
            & $updater -RepositoryRoot $catalogRoot -Subscription test-sub -PrepareRelease
            Assert-Discovery ((@($tracked | ForEach-Object { (Get-FileHash $_ -Algorithm SHA256).Hash }) -join ',') -eq $hashes) 'Identical refresh must not rewrite data or bump versions.'
            $global:AzureDiscoveryTestState.FailLifecycle = $true
            Assert-DiscoveryThrows { & $updater -RepositoryRoot $catalogRoot } '*Unable to retrieve lifecycle data*'
            $global:AzureDiscoveryTestState.Remove('FailLifecycle')
            Assert-Discovery ((@($tracked | ForEach-Object { (Get-FileHash $_ -Algorithm SHA256).Hash }) -join ',') -eq $hashes) 'Lifecycle retrieval failure must preserve catalogue and release files.'
            $global:AzureDiscoveryTestState.CloudName = 'AzureUSGovernment'
            Assert-DiscoveryThrows { & $updater -RepositoryRoot $catalogRoot } '*cloud does not match*'
            $global:AzureDiscoveryTestState.CloudName = 'AzureCloud'
            $global:AzureDiscoveryTestState.FailCatalog = $true
            Assert-DiscoveryThrows { & $updater -RepositoryRoot $catalogRoot } '*image lookup failed*'
            $global:AzureDiscoveryTestState.Remove('FailCatalog')
            $global:AzureDiscoveryTestState.ImageOffers['ubuntu-26_04-lts'] = '[]'
            $global:AzureDiscoveryTestState.ImageOffers['ubuntu-pro'] = '[]'
            Assert-DiscoveryThrows { & $updater -RepositoryRoot $catalogRoot } '*No matching images*'
            $global:AzureDiscoveryTestState.ImageOffers['ubuntu-26_04-lts'] = '[{"name":"server"}]'
            Assert-DiscoveryThrows { & $updater -RepositoryRoot $catalogRoot } '*AllowLargeRemoval*'
            Assert-Discovery ((@($tracked | ForEach-Object { (Get-FileHash $_ -Algorithm SHA256).Hash }) -join ',') -eq $hashes) 'Failed refresh modified catalogue or release files.'
            & $updater -RepositoryRoot $catalogRoot -AllowLargeRemoval -PrepareRelease
            Assert-Discovery (@((Get-Content $catalogPath -Raw | ConvertFrom-Json).Images).Count -eq 2) 'Explicit large-removal override failed.'
            $priorVersion = [version](Import-PowerShellDataFile (Join-Path $tempModuleRoot 'PwshProfile.AzureImages.psd1')).ModuleVersion
            $global:AzureDiscoveryTestState.LifecycleResponses.ubuntu = @([pscustomobject]@{ cycle = 'test'; releaseDate = '2000-01-01'; eol = '2999-02-01' })
            & $updater -RepositoryRoot $catalogRoot -PrepareRelease
            $lifecycleVersion = [version](Import-PowerShellDataFile (Join-Path $tempModuleRoot 'PwshProfile.AzureImages.psd1')).ModuleVersion
            Assert-Discovery ($lifecycleVersion.Build -eq $priorVersion.Build + 1) 'A lifecycle-only change must prepare a module update PR.'
            $global:AzureDiscoveryTestState.LifecycleResponses.ubuntu = @([pscustomobject]@{ cycle = 'replacement'; releaseDate = '2000-01-01'; eol = '2999-02-01' })
            Assert-DiscoveryThrows { & $updater -RepositoryRoot $catalogRoot } '*remove lifecycle records*'
            $global:AzureDiscoveryTestState.LifecycleResponses.ubuntu[0].cycle = 'test'
            $priorVersion = [version](Import-PowerShellDataFile (Join-Path $tempModuleRoot 'PwshProfile.AzureImages.psd1')).ModuleVersion
            $global:AzureDiscoveryTestState.CatalogRegions = '["eastus","uksouth","newregion"]'
            & $updater -RepositoryRoot $catalogRoot -PrepareRelease
            $updated = Get-Content $catalogPath -Raw | ConvertFrom-Json
            Assert-Discovery ($updated.AvailableLocations -contains 'newregion' -and $updated.Locations.Count -eq 2 -and $updated.Images.Count -eq 2) 'New completion region must not expand the Marketplace snapshot scan.'
            $regionVersion = [version](Import-PowerShellDataFile (Join-Path $tempModuleRoot 'PwshProfile.AzureImages.psd1')).ModuleVersion
            Assert-Discovery ($regionVersion.Build -eq $priorVersion.Build + 1) 'A region-only change must prepare a module update PR.'
            $updatedComputeVersion = [version](Import-PowerShellDataFile (Join-Path $tempComputeRoot 'PwshProfile.AzureCompute.psd1')).ModuleVersion
            Assert-Discovery ($updatedComputeVersion.Build -eq ([version]$computeVersion).Build + 1) 'Region changes must prepare a Compute patch release.'
            $tempComputeModule = Import-Module (Join-Path $tempComputeRoot 'PwshProfile.AzureCompute.psd1') -Force -PassThru
            Assert-Discovery ((& $tempComputeModule { $script:AzureComputeLocations }) -contains 'newregion') 'Region changes must update the independently installed Compute module.'
            $hashes = @($tracked | ForEach-Object { (Get-FileHash $_ -Algorithm SHA256).Hash }) -join ','
            $global:AzureDiscoveryTestState.CatalogRegions = '[]'
            Assert-DiscoveryThrows { & $updater -RepositoryRoot $catalogRoot } '*invalid region list*'
            $global:AzureDiscoveryTestState.CatalogRegions = '["eastus","uksouth"]'
            Assert-DiscoveryThrows { & $updater -RepositoryRoot $catalogRoot } '*Region discovery would remove*'
            Assert-Discovery ((@($tracked | ForEach-Object { (Get-FileHash $_ -Algorithm SHA256).Hash }) -join ',') -eq $hashes) 'Invalid or reduced region responses must not overwrite data.'
            'PASS: catalogue refresh, cloud guard, deterministic output, failure preservation and module release preparation.'
        } finally {
            foreach ($key in @('CatalogPublishers', 'CatalogRegions', 'CloudName', 'ImageOffers', 'FailCatalog')) { $global:AzureDiscoveryTestState.Remove($key) }
            $global:AzureDiscoveryTestState.ExitCode = 0
            Import-Module $manifest -Force
        }
        'PASS: image presets, filters, versions, Bicep, CLI arguments, errors and completion.'
    }
    if ($Module -in @('Compute', 'All')) {
        $manifest = Join-Path $PSScriptRoot '../src/modules/PwshProfile.AzureCompute/PwshProfile.AzureCompute.psd1'
        $null = Test-ModuleManifest -Path $manifest
        Import-Module $manifest -Force
        $global:AzureDiscoveryTestState.ExitCode = 0
        $fixture = @(
            [ordered]@{
                name = 'Standard_D4s_v5'; resourceType = 'virtualMachines'; locations = @('uksouth'); family = 'standardDSv5Family'
                capabilities = @(@{ name = 'vCPUs'; value = '4' }, @{ name = 'MemoryGB'; value = '16' }, @{ name = 'CpuArchitectureType'; value = 'x64' })
                locationInfo = @(@{ location = 'uksouth'; zones = @('1', '2', '3') })
                restrictions = @()
            }
            [ordered]@{
                name = 'Standard_D8ps_v5'; resourceType = 'virtualMachines'; locations = @('uksouth')
                capabilities = @(@{ name = 'vCPUs'; value = '8' }, @{ name = 'MemoryGB'; value = '32' }, @{ name = 'CpuArchitectureType'; value = 'Arm64' })
                restrictions = @(@{ type = 'Location'; values = @('uksouth'); reasonCode = 'NotAvailableForSubscription' })
            }
            [ordered]@{
                name = 'Standard_E8-2s_v5'; resourceType = 'virtualMachines'; locations = @('uksouth')
                capabilities = @(@{ name = 'vCPUs'; value = '8' }, @{ name = 'vCPUsAvailable'; value = '2' }, @{ name = 'MemoryGB'; value = '64' }, @{ name = 'CpuArchitectureType'; value = 'x64' })
                restrictions = @(@{ type = 'Zone'; values = @('uksouth'); restrictionInfo = @{ locations = @('uksouth'); zones = @('2') }; reasonCode = 'NotAvailableForSubscription' })
            }
            [ordered]@{
                name = 'Standard_A0'; resourceType = 'virtualMachines'; locations = @('uksouth')
                capabilities = @(@{ name = 'vCPUs'; value = '1' }, @{ name = 'MemoryGB'; value = '0.75' })
                restrictions = @(@{ type = 'Location'; restrictionInfo = @{ locations = @('eastus') }; reasonCode = 'NotAvailableForSubscription' })
            }
            @{ name = 'Unknown'; resourceType = 'virtualMachines'; locations = @('uksouth'); capabilities = @() }
            @{ name = 'WrongRegion'; resourceType = 'virtualMachines'; locations = @('eastus') }
            @{ name = 'Disk'; resourceType = 'disks'; locations = @('uksouth') }
        )
        $global:AzureDiscoveryTestState.Output = ConvertTo-Json -InputObject $fixture -Depth 10
        $sizes = @(Get-AzureVmSize uksouth -Subscription test-sub)
        Assert-Discovery ($sizes.Count -eq 5) 'Incorrect resource type or region filtering.'
        $call = $global:AzureDiscoveryTestState.Calls[-1]
        Assert-Discovery ($call -contains '--all' -and $call -contains 'virtualMachines' -and $call -contains 'test-sub') 'VM CLI options lost restricted sizes or subscription.'
        $filtered = @(Get-AzureVmSize uksouth -MinVCpus 4 -MaxVCpus 8 -MinMemoryGB 16 -MaxMemoryGB 32 -Architecture x64)
        Assert-Discovery ($filtered.Count -eq 1 -and $filtered[0].Name -eq 'Standard_D4s_v5') 'Numeric or architecture filters failed.'
        Assert-Discovery ($filtered[0].MemoryGB -is [double] -and $filtered[0].VCpus -is [int]) 'Capabilities should be numeric.'
        Assert-Discovery (($filtered[0].Zones -join ',') -eq '1,2,3') 'Zones not preserved.'
        $constrained = Get-AzureVmSize uksouth -Name 'Standard_E*' -MaxVCpus 2
        Assert-Discovery ($constrained.VCpus -eq 2 -and $constrained.TotalVCpus -eq 8) 'Constrained vCPUs not handled.'
        Assert-Discovery ($constrained.HasRestrictions -and $constrained.Restriction -eq 'Zone 2: NotAvailableForSubscription') 'Zone restriction lost or mislabelled.'
        $restricted = Get-AzureVmSize uksouth -Architecture Arm64
        Assert-Discovery ($restricted.HasRestrictions -and $restricted.Restriction -like 'Location:*') 'Regional restriction lost.'
        $small = Get-AzureVmSize uksouth -MaxMemoryGB 1
        Assert-Discovery ($small.Name -eq 'Standard_A0' -and $small.MemoryGB -eq 0.75) 'Fractional memory filtering failed.'
        Assert-Discovery (-not $small.HasRestrictions -and $small.Architecture -eq 'Unknown') 'Other-region restriction or absent architecture misrepresented.'
        $unknown = Get-AzureVmSize uksouth -Name Unknown
        Assert-Discovery ($null -eq $unknown.VCpus -and $null -eq $unknown.MemoryGB) 'Missing capabilities must not become zero.'
        $callCount = $global:AzureDiscoveryTestState.Calls.Count
        Assert-DiscoveryThrows { Get-AzureVmSize uksouth -MinVCpus 8 -MaxVCpus 2 } '*MinVCpus*'
        Assert-DiscoveryThrows { Get-AzureVmSize uksouth -MinMemoryGB 32 -MaxMemoryGB 16 } '*MinMemoryGB*'
        Assert-DiscoveryThrows { Get-AzureVmSize uksouth -MinVCpus 0 } '*MinVCpus*'
        Assert-Discovery ($global:AzureDiscoveryTestState.Calls.Count -eq $callCount) 'Invalid filters reached Azure.'
        Assert-Discovery ($global:AzureDiscoveryTestState.PriceCalls -eq 0 -and -not $sizes[0].PSObject.Properties['RetailHourly']) 'Default discovery must not fetch or add pricing.'
        $computeModule = (Get-Command Get-AzureVmSize).Module
        $global:AzureDiscoveryTestState.PriceCalls = 0
        $basePrice = @{
            serviceName = 'Virtual Machines'; armRegionName = 'uksouth'; currencyCode = 'USD'; type = 'Consumption'
            unitOfMeasure = '1 Hour'; isPrimaryMeterRegion = $true; tierMinimumUnits = 0
            armSkuName = 'Standard_D4s_v5'; skuName = 'D4s v5'; meterName = 'D4s v5'
            productName = 'Virtual Machines Dsv5 Series'; effectiveStartDate = '2020-01-01T00:00:00Z'; retailPrice = 0.2
        }
        $windowsPrice = $basePrice.Clone()
        $windowsPrice.productName += ' Windows'
        $windowsPrice.retailPrice = 0.4
        $spotPrice = $basePrice.Clone()
        $spotPrice.meterName += ' Spot'
        $spotPrice.retailPrice = 0.01
        $global:AzureDiscoveryTestState.PricePages = @(
            [pscustomobject]@{ Items = @([pscustomobject]$basePrice, [pscustomobject]$spotPrice); NextPageLink = 'https://prices.azure.com/api/retail/prices?page=2' }
            [pscustomobject]@{ Items = @([pscustomobject]$windowsPrice); NextPageLink = $null }
        )
        $prices = & $computeModule { Get-AzureComputeRetailPrices uksouth USD }
        Assert-Discovery ($prices['Standard_D4s_v5|Linux'].Hourly -eq 0.2 -and $prices['Standard_D4s_v5|Windows'].Hourly -eq 0.4) 'PAYG must distinguish base Linux and Windows rates and exclude Spot.'
        Assert-Discovery ($global:AzureDiscoveryTestState.PriceCalls -eq 2) 'Pricing must follow pagination.'
        $null = & $computeModule { Get-AzureComputeRetailPrices UKSouth usd }
        Assert-Discovery ($global:AzureDiscoveryTestState.PriceCalls -eq 2) 'Region and currency cache keys must be case insensitive.'
        $priced = @(Get-AzureVmSize uksouth -IncludePrice)
        $linux = $priced | Where-Object Name -EQ Standard_D4s_v5
        Assert-Discovery ($priced.Count -eq 5 -and $linux.RetailHourly -is [decimal] -and $linux.RetailHourly -eq 0.2 -and $linux.RetailMonthly -eq 146) 'Optional retail estimates must preserve all SKUs and calculate 730-hour months.'
        $windows = Get-AzureVmSize uksouth -Name Standard_D4s_v5 -IncludePrice -PriceOS Windows
        Assert-Discovery ($windows.RetailHourly -eq 0.4 -and $windows.RetailMonthly -eq 292 -and $windows.PriceOS -eq 'Windows' -and $windows.Currency -eq 'USD') 'Windows pricing must not use Linux rates.'
        Assert-Discovery ($global:AzureDiscoveryTestState.PriceCalls -eq 2) 'A regional cache must be shared across SKUs and OS selections.'
        $unpriced = @($priced | Where-Object PriceStatus -EQ Unknown)
        Assert-Discovery ($unpriced.Count -eq 4 -and @($unpriced | Where-Object { $null -ne $_.RetailHourly -or $null -ne $_.RetailMonthly }).Count -eq 0) 'Missing prices must remain Unknown with null numeric values.'
        Assert-Discovery (($priced | Where-Object Name -EQ Standard_D8ps_v5).HasRestrictions) 'Pricing must not hide subscription restrictions.'
        Assert-DiscoveryThrows { Get-AzureVmSize uksouth -Currency GBP } '*Use -IncludePrice*'
        Assert-DiscoveryThrows { Get-AzureVmSize uksouth -PriceOS Windows } '*Use -IncludePrice*'
        Assert-DiscoveryThrows { Get-AzureVmSize uksouth -IncludePrice -Currency "USD'" } '*Currency*'
        $null = Get-AzureVmSize uksouth -Name 'NoMatchingSku' -IncludePrice -Currency GBP
        Assert-Discovery ($global:AzureDiscoveryTestState.PriceCalls -eq 2) 'Empty filtered results must not query prices.'
        $global:AzureDiscoveryTestState.FailPrices = $true
        $failedPrices = @(Get-AzureVmSize uksouth -IncludePrice -Currency GBP -WarningAction SilentlyContinue -WarningVariable priceWarnings)
        Assert-Discovery ($failedPrices.Count -eq 5 -and @($failedPrices | Where-Object PriceStatus -NE Unknown).Count -eq 0 -and $priceWarnings.Count -eq 1) 'A pricing outage must warn once and preserve all size results.'
        $global:AzureDiscoveryTestState.FailPrices = $false
        $gbp = $basePrice.Clone()
        $gbp.currencyCode = 'GBP'
        $gbp.retailPrice = 0.15
        $global:AzureDiscoveryTestState.PricePages = @([pscustomobject]@{ Items = @([pscustomobject]$gbp); NextPageLink = $null })
        $british = Get-AzureVmSize uksouth -Name Standard_D4s_v5 -IncludePrice -Currency gbp
        Assert-Discovery ($british.RetailHourly -eq 0.15 -and $british.Currency -eq 'GBP') 'Failed requests must not poison the cache or mix currencies.'
        foreach ($width in @(80, 120, 160)) {
            $formatted = $priced | Out-String -Width $width
            Assert-Discovery ($formatted.Contains('PAYG/hour') -and $formatted.Contains('Est/730h') -and $formatted.Contains('0.20000') -and $formatted.Contains('Unknown')) "Default pricing display must retain estimates and unknown values at width $width."
            Assert-Discovery ($formatted.Contains('uksouth | Linux | USD') -and $formatted -notmatch '(?m)^\s*Name\s*:') 'Pricing must default to a table with region, OS and currency context, without Format-Table.'
            Assert-Discovery (($formatted -replace '\s', '').Contains('Location:NotAvailableForSubscription')) 'Narrow tables must wrap restriction details rather than truncate them.'
        }
        $singleTable = $windows | Out-String -Width 80
        Assert-Discovery ($singleTable.Contains('uksouth | Windows | USD') -and $singleTable.Contains('0.40000') -and $singleTable -notmatch '(?m)^\s*Name\s*:') 'A single priced result must also render as a table.'
        $plainTable = $sizes | Out-String -Width 80
        Assert-Discovery ($plainTable.Contains('Arch') -and $plainTable -notmatch '(?m)^\s*Name\s*:') 'Unpriced results must also default to a table.'
        Assert-Discovery ($linux.RetailHourly -is [decimal] -and $linux.PSObject.TypeNames -contains 'PwshProfile.AzureVmSize') 'Table formatting must preserve typed pipeline objects and numeric prices.'
        $distractors = @(foreach ($override in @(
                    @{ type = 'Reservation' }, @{ type = 'DevTestConsumption' }, @{ meterName = 'D4s v5 Low Priority' },
                    @{ skuName = 'D4s v5 Spot' }, @{ unitOfMeasure = '1 Month' }, @{ isPrimaryMeterRegion = $false },
                    @{ currencyCode = 'EUR' }, @{ armRegionName = 'eastus' }, @{ serviceName = 'Storage' },
                    @{ tierMinimumUnits = 1 }, @{ productName = 'Virtual Machines Dsv5 Series Red Hat' },
                    @{ effectiveStartDate = '2999-01-01T00:00:00Z' }, @{ effectiveStartDate = 'invalid' },
                    @{ retailPrice = $null }, @{ retailPrice = -1 }, @{ retailPrice = 'invalid' }
                )) {
                $candidate = $basePrice.Clone()
                $candidate.retailPrice = 0.01
                foreach ($key in $override.Keys) { $candidate[$key] = $override[$key] }
                [pscustomobject]$candidate
            })
        $global:AzureDiscoveryTestState.PricePages = @([pscustomobject]@{ Items = @([pscustomobject]$basePrice) + $distractors; NextPageLink = $null })
        & $computeModule { $script:AzureComputePriceCache.Clear() }
        $clean = Get-AzureVmSize uksouth -Name Standard_D4s_v5 -IncludePrice
        Assert-Discovery ($clean.RetailHourly -eq 0.2) 'Only current, matching, primary hourly PAYG base-compute meters may be used.'
        $conflict = $basePrice.Clone()
        $conflict.retailPrice = 0.3
        $global:AzureDiscoveryTestState.PricePages[0].Items += [pscustomobject]$conflict
        & $computeModule { $script:AzureComputePriceCache.Clear() }
        $ambiguous = Get-AzureVmSize uksouth -Name Standard_D4s_v5 -IncludePrice
        Assert-Discovery ($ambiguous.PriceStatus -eq 'Unknown' -and $null -eq $ambiguous.RetailHourly) 'Conflicting current rates must not be guessed or reduced to the cheapest.'
        $newPrice = $basePrice.Clone()
        $newPrice.effectiveStartDate = '2021-01-01T00:00:00Z'
        $newPrice.retailPrice = 0.00123
        $global:AzureDiscoveryTestState.PricePages[0].Items += [pscustomobject]$newPrice
        & $computeModule { $script:AzureComputePriceCache['uksouth|USD'].Expires = [datetime]::UtcNow.AddSeconds(-1) }
        $currentPrice = Get-AzureVmSize uksouth -Name Standard_D4s_v5 -IncludePrice
        Assert-Discovery ($currentPrice.RetailHourly -eq 0.00123 -and $currentPrice.'PAYG/hour' -eq '0.00123' -and $currentPrice.RetailMonthly -eq 0.90) 'Expired cache entries must refresh and select the newest effective price without rounding hourly data.'
        $regionPrice = $basePrice.Clone()
        $regionPrice.armRegionName = 'eastus'
        $regionPrice.retailPrice = 0.5
        $global:AzureDiscoveryTestState.PricePages = @([pscustomobject]@{ Items = @([pscustomobject]$regionPrice); NextPageLink = $null })
        $eastPrices = & $computeModule { Get-AzureComputeRetailPrices eastus USD }
        Assert-Discovery ($eastPrices['Standard_D4s_v5|Linux'].Hourly -eq 0.5) 'The cache must not mix regions.'
        foreach ($badPage in @(
                [pscustomobject]@{ Items = @([pscustomobject]$basePrice); NextPageLink = 'https://example.com/prices' }
                [pscustomobject]@{ Items = @([pscustomobject]$basePrice); NextPageLink = 'https://prices.azure.com/api/retail/prices?page=2' }
                [pscustomobject]@{ Items = 'invalid'; NextPageLink = $null }
                [pscustomobject]@{ Items = @([pscustomobject]$basePrice) }
            )) {
            & $computeModule { $script:AzureComputePriceCache.Clear() }
            $global:AzureDiscoveryTestState.PricePages = @($badPage, $badPage)
            $incomplete = Get-AzureVmSize uksouth -Name Standard_D4s_v5 -IncludePrice -WarningAction SilentlyContinue
            Assert-Discovery ($incomplete.PriceStatus -eq 'Unknown' -and $null -eq $incomplete.RetailHourly) 'Malformed or looping pagination must discard partial prices and preserve SKU results.'
        }
        'PASS: optional PAYG estimates, OS/currency selection, pagination, caching and outage handling.'
        $global:AzureDiscoveryTestState.Output = '[]'
        Assert-Discovery (@(Get-AzureVmSize uksouth).Count -eq 0) 'Empty sizes should emit no objects.'
        $global:AzureDiscoveryTestState.Output = 'not json'
        Assert-DiscoveryThrows { Get-AzureVmSize uksouth } '*invalid JSON*'
        $global:AzureDiscoveryTestState.ExitCode = 1
        $global:AzureDiscoveryTestState.Output = 'AuthorizationFailed'
        Assert-DiscoveryThrows { Get-AzureVmSize uksouth } '*size lookup failed*AuthorizationFailed*'
        $global:AzureDiscoveryTestState.ExitCode = 0
        $inputText = 'Get-AzureVmSize -Location uks'
        $completion = [System.Management.Automation.CommandCompletion]::CompleteInput($inputText, $inputText.Length, $null)
        Assert-Discovery ($completion.CompletionMatches.CompletionText -contains 'uksouth') 'VM size region completion missing.'
        $regionCatalog = Get-Content (Join-Path $PSScriptRoot '../AzureImagesCatalog.json') -Raw | ConvertFrom-Json
        $inputText = 'Get-AzureVmSize -Location '
        $completion = [System.Management.Automation.CommandCompletion]::CompleteInput($inputText, $inputText.Length, $null)
        foreach ($region in $regionCatalog.AvailableLocations) {
            Assert-Discovery ($completion.CompletionMatches.CompletionText -contains $region) "VM size region completion missing $region."
        }
        'PASS: VM size filters, capabilities, regional/zone restrictions, errors and completion.'
    }
    if ($Module -eq 'All') {
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            (Join-Path $PSScriptRoot '../src/profile/Microsoft.PowerShell_profile.ps1'), [ref]$tokens, [ref]$parseErrors)
        if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
        foreach ($functionName in @('global:Get-PwshProfile', 'global:Set-PwshProfile', 'Import-PwshProfileModules')) {
            $definition = $ast.Find({
                    param($node)
                    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $functionName
                }, $true)
            . ([scriptblock]::Create($definition.Extent.Text))
        }
        $originalAppData = $env:APPDATA
        $testRoot = Join-Path ([IO.Path]::GetTempPath()) ('azure-discovery-' + [guid]::NewGuid().ToString('N'))
        try {
            $env:APPDATA = $testRoot
            $script:PwshProfileStorePath = Join-Path $testRoot 'PwshProfile'
            $moduleRoot = Join-Path $script:PwshProfileStorePath 'modules'
            $setupAst = [System.Management.Automation.Language.Parser]::ParseFile(
                (Join-Path $PSScriptRoot '../src/Invoke-PwshProfileSetup.ps1'), [ref]$tokens, [ref]$parseErrors)
            if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
            foreach ($functionName in @('Install-PwshProfileLocalSource', 'Test-PwshProfileScriptFile', 'Install-PwshProfileAtomicFile', 'Invoke-PwshProfileUpdateTransaction')) {
                $definition = $setupAst.Find({
                        param($node)
                        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $functionName
                    }, $true)
                . ([scriptblock]::Create($definition.Extent.Text))
            }
            function Get-PwshProfileLocalStorePaths {
                @{
                    Root        = $script:PwshProfileStorePath
                    Modules     = Join-Path $script:PwshProfileStorePath 'modules'
                    Themes      = Join-Path $script:PwshProfileStorePath 'themes'
                    Functions   = Join-Path $script:PwshProfileStorePath 'functions'
                    Config      = Join-Path $script:PwshProfileStorePath 'config'
                    VersionFile = Join-Path $script:PwshProfileStorePath 'version.json'
                }
            }
            function Get-CrossPlatformSupportPaths { @{ SourceRoot = Join-Path $testRoot 'profile' } }
            function Write-PwshProfileHeader { param($Title, $Subtitle) }
            function Write-PwshProfileStatus { param($Stage, $Type, $Message) }
            $installed = Invoke-PwshProfileUpdateTransaction {
                Install-PwshProfileLocalSource -SourceRoot (Join-Path $PSScriptRoot '../src') -Bootstrap
            }
            Assert-Discovery ($installed -eq $true) 'Local installation failed.'
            $baseline = Get-Content (Join-Path $script:PwshProfileStorePath 'version.json') -Raw | ConvertFrom-Json
            foreach ($moduleName in @('AzureImages', 'AzureCompute')) {
                $assetTypes = @('Manifest', 'Script', 'Format')
                foreach ($assetType in $assetTypes) {
                    $key = $moduleName.Substring(0, 1).ToLowerInvariant() + $moduleName.Substring(1) + $assetType
                    $artifact = $baseline.artifacts.$key
                    Assert-Discovery ([bool]$artifact) "Missing installation baseline entry: $key"
                    $path = Join-Path $moduleRoot "PwshProfile.$moduleName/$($artifact.file)"
                    Assert-Discovery ((Get-FileHash $path -Algorithm SHA256).Hash -ieq $artifact.sha256) "Installed module hash mismatch: $key"
                }
            }
            $artifactMaps = @($setupAst.FindAll({
                        param($node)
                        $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                        $node.Left.Extent.Text -eq '$artifactNames' -and $node.Right.Extent.Text -like '*azureKubernetesManifest*'
                    }, $true))
            Assert-Discovery ($artifactMaps.Count -eq 2) 'Expected local and published bundle asset maps.'
            foreach ($assignment in $artifactMaps) {
                $assetNames = & ([scriptblock]::Create($assignment.Right.Extent.Text))
                foreach ($key in @('azureImagesManifest', 'azureImagesScript', 'azureImagesFormat', 'azureComputeManifest', 'azureComputeScript', 'azureComputeFormat')) {
                    Assert-Discovery ($assetNames[$key] -eq $baseline.artifacts.$key.file) "Bundle asset mapping differs from installation: $key"
                }
            }
            'PASS: local bundle installation, module hashes and published bundle asset names.'
            $settings = Get-PwshProfile -SettingsOnly
            Assert-Discovery (-not $settings.EnableAzureImages -and -not $settings.EnableAzureCompute) 'New modules must default to disabled.'
            Set-PwshProfile -EnableAzureImages
            Set-PwshProfile -EnableAzureCompute
            $settings = Get-PwshProfile -SettingsOnly
            Assert-Discovery ($settings.EnableAzureImages -and $settings.EnableAzureCompute) 'Enabling a module reset its sibling setting.'
            Assert-Discovery ($settings.EnabledModules -contains 'PwshProfile.AzureImages' -and $settings.EnabledModules -contains 'PwshProfile.AzureCompute') 'Module status missing.'
            Remove-Module PwshProfile.AzureImages, PwshProfile.AzureCompute
            Import-PwshProfileModules -Settings $settings
            Assert-Discovery ([bool](Get-Command Get-AzureVmImage -ErrorAction Ignore)) 'Image module not loaded on profile reload.'
            Assert-Discovery ([bool](Get-Command Get-AzureVmSize -ErrorAction Ignore)) 'Compute module not loaded on profile reload.'
            Set-PwshProfile -EnableAzureImages:$false
            Assert-Discovery (-not (Get-Command Get-AzureVmImage -ErrorAction Ignore)) 'Disabled image module still loaded.'
            Assert-Discovery ((Get-PwshProfile -SettingsOnly).EnableAzureCompute) 'Disabling images reset compute.'
            Set-PwshProfile -EnableAzureCompute:$false
            Assert-Discovery (-not (Get-Command Get-AzureVmSize -ErrorAction Ignore)) 'Disabled compute module still loaded.'
            'PASS: profile defaults, settings persistence, module status, reload and disable.'
        } finally {
            $env:APPDATA = $originalAppData
            Remove-Module PwshProfile.AzureImages, PwshProfile.AzureCompute -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $testRoot -Recurse -Force
            Remove-Item Function:/Get-PwshProfile, Function:/Set-PwshProfile, Function:/Import-PwshProfileModules
        }
    }
} finally {
    Remove-Module PwshProfile.AzureImages, PwshProfile.AzureCompute -ErrorAction SilentlyContinue
    if ($catalogRoot -and (Test-Path $catalogRoot)) { Remove-Item $catalogRoot -Recurse -Force }
    Remove-Item Function:/az -ErrorAction SilentlyContinue
    Remove-Item Function:/Invoke-RestMethod -ErrorAction SilentlyContinue
    Remove-Variable AzureDiscoveryTestState -Scope Global -ErrorAction SilentlyContinue
}
