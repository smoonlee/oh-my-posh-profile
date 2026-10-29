$script:AzureComputeLocations = @'
[
    "eastus", "westus2", "australiaeast", "southeastasia", "northeurope", "swedencentral",
    "westeurope", "uksouth", "centralus", "southafricanorth", "centralindia", "eastasia",
    "indiasouthcentral", "indonesiacentral", "japaneast", "japanwest", "koreacentral",
    "malaysiawest", "newzealandnorth", "canadacentral", "austriaeast", "belgiumcentral",
    "denmarkeast", "francecentral", "germanywestcentral", "italynorth", "norwayeast",
    "polandcentral", "spaincentral", "switzerlandnorth", "mexicocentral", "uaenorth",
    "brazilsouth", "chilecentral", "eastus2euap", "israelcentral", "qatarcentral",
    "eastus2", "eastusstg", "southcentralus", "westus3", "northcentralus", "westus",
    "jioindiawest", "centraluseuap", "southcentralusstg", "westcentralus", "southafricawest",
    "australiacentral", "australiacentral2", "australiasoutheast", "jioindiacentral",
    "koreasouth", "southindia", "westindia", "canadaeast", "francesouth", "germanynorth",
    "norwaywest", "switzerlandwest", "uaecentral", "brazilsoutheast", "ukwest"
]
'@ | ConvertFrom-Json

function Invoke-AzureComputeCli {
    param([string[]] $Arguments)

    $azCommand = Get-Command -Name az -ErrorAction Ignore
    if (-not $azCommand) {
        throw 'Azure CLI (az) was not found. Install Azure CLI and sign in with az login, then try again.'
    }

    $ErrorActionPreference = 'Continue'
    $PSNativeCommandUseErrorActionPreference = $false
    $output = & $azCommand @Arguments --output json --only-show-errors 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Azure VM size lookup failed. Check az login and your subscription permissions. $(($output | Out-String).Trim())"
    }

    $json = ($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | Out-String).Trim()
    try {
        if (-not $json) { throw 'Empty response.' }
        $result = ConvertFrom-Json -InputObject $json -ErrorAction Stop
        if ($json -notmatch '^\[') { throw 'Expected an array.' }
        $result
    } catch {
        throw "Azure CLI returned invalid JSON for the VM size lookup. $($_.Exception.Message)"
    }
}

$script:AzureComputePriceCache = @{}

function Get-AzureComputeRetailPrices {
    param([string] $Location, [string] $Currency)

    $cacheKey = '{0}|{1}' -f $Location.ToLowerInvariant(), $Currency.ToUpperInvariant()
    $cached = $script:AzureComputePriceCache[$cacheKey]
    if ($cached -and $cached.Expires -gt [datetime]::UtcNow) { return $cached.Prices }
    $prices = @{}
    try {
        $filter = "serviceName eq 'Virtual Machines' and armRegionName eq '$($Location.ToLowerInvariant().Replace("'", "''"))' and priceType eq 'Consumption'"
        $nextPage = "https://prices.azure.com/api/retail/prices?api-version=2023-01-01-preview&currencyCode='$($Currency.ToUpperInvariant())'&meterRegion='primary'&`$filter=$([uri]::EscapeDataString($filter))"
        $visited = @{}
        $retrievedAt = [datetime]::UtcNow
        while ($nextPage) {
            $pageUri = [uri]$nextPage
            if ($pageUri.Scheme -ne 'https' -or $pageUri.Host -ne 'prices.azure.com' -or
                $pageUri.Port -ne 443 -or $pageUri.UserInfo -or $pageUri.AbsolutePath -ne '/api/retail/prices' -or
                $visited.ContainsKey($nextPage) -or $visited.Count -ge 100) {
                throw 'Invalid or repeated retail pricing page link.'
            }
            $visited[$nextPage] = $true
            $page = Invoke-RestMethod -Uri $pageUri -Headers @{ 'User-Agent' = 'pwsh-profile-azure-compute' } -TimeoutSec 30 -ErrorAction Stop
            if ($page.Items -isnot [array] -or -not $page.PSObject.Properties['NextPageLink']) {
                throw 'Invalid retail pricing response.'
            }
            foreach ($item in $page.Items) {
                if ($item.serviceName -ne 'Virtual Machines' -or $item.armRegionName -ne $Location -or
                    $item.currencyCode -ne $Currency -or $item.type -ne 'Consumption' -or
                    $item.unitOfMeasure -ne '1 Hour' -or $item.isPrimaryMeterRegion -isnot [bool] -or
                    -not $item.isPrimaryMeterRegion -or $null -eq $item.tierMinimumUnits -or $item.tierMinimumUnits -ne 0 -or
                    -not $item.armSkuName -or "$($item.skuName) $($item.meterName)" -match '(?i)spot|low[\s-]*priority' -or
                    $item.productName -notmatch '^Virtual Machines .+ Series(?<windows> Windows)?$') { continue }
                $priceOS = if ($Matches.windows) { 'Windows' } else { 'Linux' }
                $effectiveDate = [datetimeoffset]::MinValue
                $hourly = [decimal]0
                if (-not [datetimeoffset]::TryParse([string]$item.effectiveStartDate, [Globalization.CultureInfo]::InvariantCulture,
                        [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$effectiveDate) -or
                    $effectiveDate.UtcDateTime -gt $retrievedAt -or $null -eq $item.retailPrice -or
                    -not [decimal]::TryParse([string]$item.retailPrice, [Globalization.NumberStyles]::Float,
                        [Globalization.CultureInfo]::InvariantCulture, [ref]$hourly) -or $hourly -lt 0) { continue }
                $key = '{0}|{1}' -f $item.armSkuName, $priceOS
                $existing = $prices[$key]
                if (-not $existing -or $effectiveDate -gt $existing.EffectiveDate) {
                    $prices[$key] = [pscustomobject]@{
                        Hourly = $hourly; EffectiveDate = $effectiveDate; RetrievedAt = $retrievedAt; Ambiguous = $false
                    }
                } elseif ($effectiveDate -eq $existing.EffectiveDate -and $hourly -ne $existing.Hourly) {
                    $existing.Ambiguous = $true
                }
            }
            $nextPage = [string]$page.NextPageLink
        }
        $script:AzureComputePriceCache[$cacheKey] = @{ Prices = $prices; Expires = [datetime]::UtcNow.AddHours(1) }
        return $prices
    } catch {
        Write-Warning "PAYG retail estimates unavailable for '$Location' in $Currency. VM size discovery will continue without prices. $($_.Exception.Message)"
        return @{}
    }
}

function Get-AzureVmSize {
    <#
  .SYNOPSIS
      Finds Azure VM sizes and subscription restrictions in a region.
  .DESCRIPTION
      Uses Azure CLI resource SKUs, including restricted sizes. Returns numeric
      CPU/memory properties, architecture, zones, and regional restriction details.
      VCpus uses vCPUsAvailable for constrained-core sizes, otherwise vCPUs.
      TotalVCpus retains vCPUs. Missing capabilities remain null or Unknown.
      No restrictions does not guarantee capacity, quota or image compatibility.
    Pricing is opt-in. This command never queries quota usage or creates resources.
  .PARAMETER Location
      Azure region, for example uksouth.
  .PARAMETER Name
      VM size wildcard pattern, for example Standard_D*s_v5.
  .PARAMETER MinVCpus
      Minimum enabled vCPU count (inclusive).
  .PARAMETER MaxVCpus
      Maximum enabled vCPU count (inclusive).
  .PARAMETER MinMemoryGB
      Minimum memory in GB (inclusive).
  .PARAMETER MaxMemoryGB
      Maximum memory in GB (inclusive).
  .PARAMETER Architecture
      Filter by the reported CPU architecture, x64 or Arm64.
  .PARAMETER Subscription
      Subscription name or ID. Defaults to the Azure CLI active subscription.
  .PARAMETER IncludePrice
      Add public PAYG retail hourly and monthly estimates, not your actual bill.
      Monthly estimates assume 730 running hours. Excludes disks, networking,
      Marketplace software, discounts, Spot, reservations and savings plans.
      Successful regional price responses are cached for one hour. Missing,
      ambiguous or unavailable prices have PriceStatus Unknown and null amounts.
  .PARAMETER PriceOS
      Linux base compute or Windows license-included retail pricing. Defaults to
      Linux. Requires IncludePrice and does not filter VM/image compatibility.
  .PARAMETER Currency
      Three-letter pricing currency, default USD. Requires IncludePrice.
      Non-USD rates are reference estimates, not contractual exchange rates.
  .EXAMPLE
      Get-AzureVmSize -Location uksouth -MinVCpus 4 -MaxVCpus 8 -MinMemoryGB 16
  .EXAMPLE
      Get-AzureVmSize -Location uksouth -Name 'Standard_D*s_v5' -Architecture x64
  .EXAMPLE
      Get-AzureVmSize -Location uksouth -Name Standard_D4s_v5 | Format-List *
  .EXAMPLE
      Get-AzureVmSize uksouth -Name 'Standard_D*s_v5' -IncludePrice -PriceOS Windows -Currency GBP
  #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Location,

        [ValidateNotNullOrEmpty()]
        [string] $Name = '*',

        [ValidateRange(1, [int]::MaxValue)]
        [int] $MinVCpus,

        [ValidateRange(1, [int]::MaxValue)]
        [int] $MaxVCpus,

        [ValidateRange(0.01, [double]::MaxValue)]
        [double] $MinMemoryGB,

        [ValidateRange(0.01, [double]::MaxValue)]
        [double] $MaxMemoryGB,

        [ValidateSet('x64', 'Arm64')]
        [string] $Architecture,

        [ValidateNotNullOrEmpty()]
        [string] $Subscription,

        [switch] $IncludePrice,

        [ValidateSet('Linux', 'Windows')]
        [string] $PriceOS = 'Linux',

        [ValidatePattern('\A[A-Za-z]{3}\z')]
        [string] $Currency = 'USD'
    )

    if ($MaxVCpus -and $MinVCpus -gt $MaxVCpus) { throw 'MinVCpus must not exceed MaxVCpus.' }
    if ($MaxMemoryGB -and $MinMemoryGB -gt $MaxMemoryGB) { throw 'MinMemoryGB must not exceed MaxMemoryGB.' }
    if (-not $IncludePrice -and ($PSBoundParameters.ContainsKey('PriceOS') -or $PSBoundParameters.ContainsKey('Currency'))) {
        throw 'Use -IncludePrice with -PriceOS or -Currency.'
    }
    $Currency = $Currency.ToUpperInvariant()
    $PriceOS = if ($PriceOS -eq 'Windows') { 'Windows' } else { 'Linux' }
    $priceLookup = $null
    $arguments = @('vm', 'list-skus', '--location', $Location, '--resource-type', 'virtualMachines', '--all')
    if ($PSBoundParameters.ContainsKey('Subscription')) {
        $arguments += @('--subscription', $Subscription)
    }
    Write-Progress -Activity 'Get-AzureVmSize' -Status "Querying VM sizes in '$Location'..."
    try {
        $sizes = @(Invoke-AzureComputeCli -Arguments $arguments)
    } finally {
        Write-Progress -Activity 'Get-AzureVmSize' -Completed
    }

    foreach ($size in ($sizes | Sort-Object name)) {
        if ($size.resourceType -ne 'virtualMachines' -or @($size.locations) -notcontains $Location) { continue }
        if (-not $size.name) { throw 'Azure CLI returned a VM size without a name.' }
        if ($size.name -notlike $Name) { continue }
        $capabilities = @{}
        foreach ($capability in $size.capabilities) {
            $capabilities[$capability.name] = $capability.value
        }
        $totalVCpus = if ($capabilities.ContainsKey('vCPUs')) { [int]$capabilities.vCPUs } else { $null }
        $vcpus = if ($capabilities.ContainsKey('vCPUsAvailable')) { [int]$capabilities.vCPUsAvailable } else { $totalVCpus }
        $memoryGB = if ($capabilities.ContainsKey('MemoryGB')) { [double]$capabilities.MemoryGB } else { $null }
        $cpuArchitecture = if ($capabilities.CpuArchitectureType) { [string]$capabilities.CpuArchitectureType } else { 'Unknown' }
        if (($MinVCpus -or $MaxVCpus) -and $null -eq $vcpus) { continue }
        if (($MinMemoryGB -or $MaxMemoryGB) -and $null -eq $memoryGB) { continue }
        if ($MinVCpus -and $vcpus -lt $MinVCpus) { continue }
        if ($MaxVCpus -and $vcpus -gt $MaxVCpus) { continue }
        if ($MinMemoryGB -and $memoryGB -lt $MinMemoryGB) { continue }
        if ($MaxMemoryGB -and $memoryGB -gt $MaxMemoryGB) { continue }
        if ($Architecture -and $cpuArchitecture -ne $Architecture) { continue }

        $restrictions = @($size.restrictions | Where-Object {
                if ($null -eq $_) { return $false }
                $regions = @($_.restrictionInfo.locations | Where-Object { $_ })
                if (-not $regions.Count) { $regions = @($_.values | Where-Object { $_ }) }
                -not $regions.Count -or $regions -contains $Location
            })
        $restrictionSummary = @(
            foreach ($restriction in $restrictions) {
                $scope = [string]$restriction.type
                if ($restriction.type -eq 'Zone') {
                    $scope += ' ' + (@($restriction.restrictionInfo.zones) -join ',')
                }
                '{0}: {1}' -f $scope.Trim(), $restriction.reasonCode
            }
        ) -join '; '
        if (-not $restrictionSummary) { $restrictionSummary = 'None' }
        $result = [pscustomobject][ordered]@{
            PSTypeName      = 'PwshProfile.AzureVmSize'
            Name            = [string]$size.name
            Location        = $Location
            VCpus           = $vcpus
            TotalVCpus      = $totalVCpus
            MemoryGB        = $memoryGB
            Architecture    = $cpuArchitecture
            Family          = [string]$size.family
            Zones           = @($size.locationInfo | Where-Object { $_.location -eq $Location } | ForEach-Object { $_.zones } | Sort-Object -Unique)
            HasRestrictions = $restrictions.Count -gt 0
            Restriction     = $restrictionSummary
            Restrictions    = $restrictions
            Capabilities    = $capabilities
        }
        $displayProperties = @('Name', 'VCpus', 'MemoryGB', 'Architecture', 'Restriction')
        if ($IncludePrice) {
            $result.PSObject.TypeNames.Insert(0, 'PwshProfile.AzureVmSize.Priced')
            if ($null -eq $priceLookup) { $priceLookup = Get-AzureComputeRetailPrices -Location $Location -Currency $Currency }
            $price = $priceLookup[('{0}|{1}' -f $size.name, $PriceOS)]
            $available = $null -ne $price -and -not $price.Ambiguous
            $result | Add-Member -NotePropertyMembers ([ordered]@{
                    PriceOS            = $PriceOS
                    Currency           = $Currency
                    RetailHourly       = $(if ($available) { $price.Hourly } else { $null })
                    RetailMonthly      = $(if ($available) { [decimal]::Round($price.Hourly * 730, 2) } else { $null })
                    MonthlyHours       = 730
                    PriceStatus        = $(if ($available) { 'Available' } else { 'Unknown' })
                    PriceEffectiveDate = $(if ($available) { $price.EffectiveDate } else { $null })
                    PriceRetrievedAt   = $(if ($available) { $price.RetrievedAt } else { $null })
                    PriceSource        = 'https://prices.azure.com/api/retail/prices'
                })
            $result | Add-Member -MemberType ScriptProperty -Name 'PAYG/hour' -Value {
                if ($null -eq $this.RetailHourly) { 'Unknown' }
                else { $this.RetailHourly.ToString('0.00000', [Globalization.CultureInfo]::InvariantCulture) }
            }
            $result | Add-Member -MemberType ScriptProperty -Name 'Est/730h' -Value {
                if ($null -eq $this.RetailMonthly) { 'Unknown' }
                else { $this.RetailMonthly.ToString('0.00', [Globalization.CultureInfo]::InvariantCulture) }
            }
            $displayProperties = @('Name', 'VCpus', 'MemoryGB', 'PriceOS', 'Currency', 'PAYG/hour', 'Est/730h', 'Restriction')
        }
        $display = [System.Management.Automation.PSPropertySet]::new('DefaultDisplayPropertySet', [string[]]$displayProperties)
        $result | Add-Member -MemberType MemberSet -Name PSStandardMembers -Value ([System.Management.Automation.PSMemberInfo[]]@($display))
        $result
    }
}

Register-ArgumentCompleter -CommandName Get-AzureVmSize -ParameterName Location -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    @($script:AzureComputeLocations | Sort-Object -Unique) |
    Where-Object { $_ -like "$wordToComplete*" } |
    ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}

Export-ModuleMember -Function Get-AzureVmSize
