# Common Azure regions for AKS; shared by -ListRegions and the -Location tab completer.
$script:AksCommonRegions = @(
  'eastus', 'eastus2', 'westus', 'westus2', 'westus3',
  'canadacentral', 'canadaeast',
  'northeurope', 'westeurope', 'francecentral', 'germanynorth', 'germanywestcentral', 'switzerlandnorth', 'switzerlandwest', 'uksouth', 'ukwest',
  'japaneast', 'japanwest', 'koreacentral', 'koreasouth',
  'southeastasia', 'australiaeast', 'australiasoutheast', 'newzealandnorth',
  'southcentralus', 'southindia', 'centralindia', 'northindia',
  'brazilsouth', 'brazilsoutheast',
  'norwaywest', 'norwayeast',
  'uaenorth', 'qatarcentral',
  'southafricanorth', 'southafricawest'
) | Sort-Object

function Get-AksVersion {
  <#
  .SYNOPSIS
      Gets Kubernetes versions currently available for Azure Kubernetes Service in a region.

  .DESCRIPTION
      Uses Azure CLI to return structured version information from
      `az aks get-versions`. Preview versions are excluded by default. Use
      -IncludePreview to include them. Use -OpenReleaseTracker to open the AKS
      release tracker instead of querying Azure CLI.

  .PARAMETER Location
      Azure region name, such as eastus or australiaeast.

  .PARAMETER Subscription
      Azure subscription name or ID used for this query. When omitted, Azure CLI
      uses its active subscription.

  .PARAMETER IncludePreview
      Include Kubernetes versions marked as preview by AKS.

  .PARAMETER OpenReleaseTracker
      Open the AKS Kubernetes version release tracker in the default browser.

  .PARAMETER ListRegions
      List commonly available Azure regions for AKS.

  .EXAMPLE
      Get-AksVersion -Location eastus

  .EXAMPLE
      Get-AksVersion -Location australiaeast -IncludePreview

  .EXAMPLE
      Get-AksVersion -OpenReleaseTracker

  .EXAMPLE
      Get-AksVersion -ListRegions
  #>
  [CmdletBinding(DefaultParameterSetName = 'Versions')]
  [OutputType([pscustomobject])]
  param (
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Versions')]
    [ValidateNotNullOrEmpty()]
    [string] $Location,

    [Parameter(ParameterSetName = 'Versions')]
    [ValidateNotNullOrEmpty()]
    [string] $Subscription,

    [Parameter(ParameterSetName = 'Versions')]
    [switch] $IncludePreview,

    [Parameter(Mandatory, ParameterSetName = 'ReleaseTracker')]
    [switch] $OpenReleaseTracker,

    [Parameter(Mandatory, ParameterSetName = 'ListRegions')]
    [switch] $ListRegions
  )

  if ($ListRegions) {
    return $script:AksCommonRegions
  }

  if ($OpenReleaseTracker) {
    try {
      Start-Process 'https://releases.aks.azure.com/KubernetesVersions' -ErrorAction Stop
    }
    catch {
      Write-Warning "Could not open the AKS release tracker. $($_.Exception.Message)"
    }
    return
  }

  $azCommand = Get-Command -Name az -ErrorAction Ignore
  if (-not $azCommand) {
    throw 'Azure CLI (az) was not found. Install Azure CLI, sign in with az login, then run the command again.'
  }

  $arguments = @(
    'aks', 'get-versions',
    '--location', $Location,
    '--output', 'json',
    '--only-show-errors'
  )
  if ($PSBoundParameters.ContainsKey('Subscription')) {
    $arguments += @('--subscription', $Subscription)
  }

  Write-Progress -Activity 'Get-AksVersion' -Status "Querying Azure CLI for '$Location'..."
  try {
    $output = & $azCommand.Name @arguments 2>&1
  }
  finally {
    Write-Progress -Activity 'Get-AksVersion' -Completed
  }
  if ($LASTEXITCODE -ne 0) {
    $details = ($output | Out-String).Trim()
    if (-not $details) {
      $details = 'Azure CLI did not return an error message.'
    }
    throw "Could not retrieve AKS versions for '$Location'. $details"
  }

  try {
    $result = ($output | Out-String) | ConvertFrom-Json -ErrorAction Stop
  }
  catch {
    throw "Azure CLI returned invalid JSON for AKS versions in '$Location'. $($_.Exception.Message)"
  }

  if ($null -ne $result.orchestrators) {
    # Older az CLI versions return a flat orchestrators array with per-patch metadata.
    foreach ($version in @($result.orchestrators)) {
      $isPreview = [bool]$version.isPreview
      if ($isPreview -and -not $IncludePreview) {
        continue
      }

      [pscustomobject][ordered]@{
        Location = $Location
        KubernetesVersion = [string]$version.orchestratorVersion
        IsDefault = [bool]$version.default
        IsPreview = $isPreview
      }
    }
    return
  }

  # Current az CLI versions group patch versions under each minor version entry.
  foreach ($minorVersion in @($result.values)) {
    $isPreview = [bool]$minorVersion.isPreview
    if ($isPreview -and -not $IncludePreview) {
      continue
    }
    $isDefault = [bool]$minorVersion.isDefault

    foreach ($patchVersion in @($minorVersion.patchVersions.PSObject.Properties.Name)) {
      [pscustomobject][ordered]@{
        Location = $Location
        KubernetesVersion = $patchVersion
        IsDefault = $isDefault
        IsPreview = $isPreview
      }
    }
  }
}

Register-ArgumentCompleter -CommandName Get-AksVersion -ParameterName Location -ScriptBlock {
  param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
  $script:AksCommonRegions |
    Where-Object { $_ -like "$wordToComplete*" } |
    ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}

Export-ModuleMember -Function Get-AksVersion
