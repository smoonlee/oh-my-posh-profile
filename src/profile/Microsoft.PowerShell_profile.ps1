<#
.SYNOPSIS
    PowerShell profile configuration.
#>

$script:PwshProfileVersion = '4.0.0'
$script:PwshProfileRepository = 'smoonlee/oh-my-posh-profile'
$script:PwshProfileStorePath = Join-Path $env:APPDATA 'PwshProfile'
$global:PwshProfileVersion = $script:PwshProfileVersion

function global:Get-PwshProfileReleasePages {
  [CmdletBinding()]
  param([string] $Uri, [hashtable] $Headers, [int] $TimeoutSec = 15)
  for ($page = 1; ; $page++) {
    # Invoke-RestMethod returns the JSON array as one pipeline object.
    # Assign it directly so filtering and pagination see individual releases.
    $items = Invoke-RestMethod -Uri "$Uri&page=$page" -Headers $Headers -TimeoutSec $TimeoutSec -ErrorAction Stop
    $items
    if ($items.Count -lt 100) { break }
  }
}

function global:Compare-PwshProfileSemanticVersion {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $Left,

    [Parameter(Mandatory)]
    [string] $Right
  )

  $parseVersion = {
    param([string] $Value)

    $pattern = '^(?<core>(?<major>0|[1-9]\d*)\.(?<minor>0|[1-9]\d*)\.(?<patch>0|[1-9]\d*))(?:-(?<prerelease>(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*))?(?:\+(?<build>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$'
    if ($Value -notmatch $pattern) {
      throw "'$Value' is not a valid SemVer 2.0 version."
    }

    [pscustomobject]@{
      Core       = [version]$Matches.core
      Prerelease = if ($Matches.prerelease) { @($Matches.prerelease -split '\.') } else { @() }
    }
  }

  $leftVersion = & $parseVersion $Left
  $rightVersion = & $parseVersion $Right
  $coreComparison = $leftVersion.Core.CompareTo($rightVersion.Core)
  if ($coreComparison -ne 0) {
    return [Math]::Sign($coreComparison)
  }

  if ($leftVersion.Prerelease.Count -eq 0 -and $rightVersion.Prerelease.Count -eq 0) { return 0 }
  if ($leftVersion.Prerelease.Count -eq 0) { return 1 }
  if ($rightVersion.Prerelease.Count -eq 0) { return -1 }

  $identifierCount = [Math]::Max($leftVersion.Prerelease.Count, $rightVersion.Prerelease.Count)
  for ($index = 0; $index -lt $identifierCount; $index++) {
    if ($index -ge $leftVersion.Prerelease.Count) { return -1 }
    if ($index -ge $rightVersion.Prerelease.Count) { return 1 }

    $leftIdentifier = $leftVersion.Prerelease[$index]
    $rightIdentifier = $rightVersion.Prerelease[$index]
    $leftIsNumeric = $leftIdentifier -match '^\d+$'
    $rightIsNumeric = $rightIdentifier -match '^\d+$'
    if ($leftIsNumeric -and $rightIsNumeric) {
      $identifierComparison = [System.Numerics.BigInteger]::Parse($leftIdentifier).CompareTo(
        [System.Numerics.BigInteger]::Parse($rightIdentifier)
      )
    } elseif ($leftIsNumeric) {
      $identifierComparison = -1
    } elseif ($rightIsNumeric) {
      $identifierComparison = 1
    } else {
      $identifierComparison = [string]::CompareOrdinal($leftIdentifier, $rightIdentifier)
    }
    if ($identifierComparison -ne 0) {
      return [Math]::Sign($identifierComparison)
    }
  }

  0
}

function global:Get-PwshProfile {
  [CmdletBinding()]
  param (
    [switch] $SettingsOnly
  )

  $storePath = Join-Path $env:APPDATA 'PwshProfile'
  $configPath = Join-Path $storePath 'config\settings.json'
  $enablePreReleaseUpdate = $false
  $enablePublicIP = $false
  $enableNetworkCidr = $false
  $enableEndOfLife = $false
  $enableAzureKubernetes = $false
  $enableDns = $false
  $enableTlsCertificate = $false
  if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    try {
      $settings = Get-Content -LiteralPath $configPath -Raw -ErrorAction Stop |
      ConvertFrom-Json -ErrorAction Stop
      $enablePreReleaseUpdate = [bool]$settings.enablePreReleaseUpdate
      $enablePublicIP = [bool]$settings.enablePublicIP
      $enableNetworkCidr = [bool]$settings.enableNetworkCidr
      $enableEndOfLife = [bool]$settings.enableEndOfLife
      $enableAzureKubernetes = [bool]$settings.enableAzureKubernetes
      $enableDns = [bool]$settings.enableDns
      $enableTlsCertificate = [bool]$settings.enableTlsCertificate
    } catch {
      Write-Warning "Ignoring invalid Pwsh Profile settings at '$configPath'."
    }
  }

  $stableVersion = $null
  $previewVersion = $null
  $latestIndependentModuleVersions = @{}
  $remoteQuerySucceeded = $false
  if (-not $SettingsOnly) {
    try {
      $releases = Get-PwshProfileReleasePages `
        -Uri 'https://api.github.com/repos/smoonlee/oh-my-posh-profile/releases?per_page=100' `
        -Headers @{ 'User-Agent' = 'pwsh-profile-status' } `
        -TimeoutSec 15 `
        -ErrorAction Stop
      $remoteQuerySucceeded = $true
      foreach ($release in @($releases | Where-Object { -not $_.draft })) {
        if ([string]$release.tag_name -match '^(?<moduleName>PwshProfile\.[A-Za-z0-9_.-]+)-v(?<moduleVersion>(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*))$' -and
          -not $release.prerelease) {
          $candidateModuleName = $Matches.moduleName
          $candidateModuleVersion = $Matches.moduleVersion
          if (-not $latestIndependentModuleVersions.ContainsKey($candidateModuleName) -or
            (Compare-PwshProfileSemanticVersion -Left $candidateModuleVersion -Right $latestIndependentModuleVersions[$candidateModuleName]) -gt 0) {
            $latestIndependentModuleVersions[$candidateModuleName] = $candidateModuleVersion
          }
        }
        if ([string]$release.tag_name -notmatch '^v(?<version>(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:-(?<prerelease>(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?)$') {
          continue
        }

        $candidateVersion = $Matches.version
        $isPreview = [bool]$Matches.prerelease
        if ([bool]$release.prerelease -ne $isPreview) {
          continue
        }

        if ($isPreview) {
          if (-not $previewVersion -or
            (Compare-PwshProfileSemanticVersion -Left $candidateVersion -Right $previewVersion) -gt 0) {
            $previewVersion = $candidateVersion
          }
        } elseif (-not $stableVersion -or
          (Compare-PwshProfileSemanticVersion -Left $candidateVersion -Right $stableVersion) -gt 0) {
          $stableVersion = $candidateVersion
        }
      }
    } catch {
      Write-Warning "Could not query published Pwsh Profile versions. $($_.Exception.Message)"
    }
  }

  $optionalModules = @(
    [pscustomobject]@{
      Name        = 'PwshProfile.PublicIP'
      Enabled     = $enablePublicIP
      Description = 'Look up public IP address details'
    }
    [pscustomobject]@{
      Name        = 'PwshProfile.NetworkCidr'
      Enabled     = $enableNetworkCidr
      Description = 'Subnet / CIDR range calculator'
    }
    [pscustomobject]@{
      Name        = 'PwshProfile.EndOfLife'
      Enabled     = $enableEndOfLife
      Description = 'Product end-of-life and support lookup'
    }
    [pscustomobject]@{
      Name        = 'PwshProfile.AzureKubernetes'
      Enabled     = $enableAzureKubernetes
      Description = 'AKS version and upgrade helper'
    }
    [pscustomobject]@{
      Name        = 'PwshProfile.Dns'
      Enabled     = $enableDns
      Description = 'DNS resolution helper'
    }
    [pscustomobject]@{
      Name        = 'PwshProfile.TlsCertificate'
      Enabled     = $enableTlsCertificate
      Description = 'TLS certificate inspection and PFX tools'
    }
  )
  $selectedRemoteVersion = if ($enablePreReleaseUpdate) {
    $previewVersion
  } else {
    $stableVersion
  }
  $bundleUpdateAvailable = $false
  if ($selectedRemoteVersion) {
    try {
      $bundleUpdateAvailable = (Compare-PwshProfileSemanticVersion `
          -Left $selectedRemoteVersion `
          -Right $global:PwshProfileVersion) -gt 0
    } catch {
      $bundleUpdateAvailable = $false
    }
  }

  $moduleStatuses = @(
    foreach ($module in $optionalModules) {
      $modulePath = Join-Path $storePath "modules\$($module.Name)\$($module.Name).psd1"
      $moduleVersion = $null
      $moduleInstalled = Test-Path -LiteralPath $modulePath -PathType Leaf
      if ($moduleInstalled) {
        try {
          $moduleManifest = Import-PowerShellDataFile -LiteralPath $modulePath -ErrorAction Stop
          if ($moduleManifest.ModuleVersion) {
            $moduleVersion = [string]$moduleManifest.ModuleVersion
          }
        } catch {
          $moduleVersion = 'Invalid manifest'
        }
      }

      $latestModuleVersion = if ($latestIndependentModuleVersions.ContainsKey($module.Name)) {
        $latestIndependentModuleVersions[$module.Name]
      } else { $null }
      $moduleUpdateAvailable = $bundleUpdateAvailable
      if ($moduleInstalled -and $moduleVersion -and $latestModuleVersion) {
        try {
          $moduleUpdateAvailable = (Compare-PwshProfileSemanticVersion `
              -Left $latestModuleVersion `
              -Right $moduleVersion) -gt 0
        } catch {
          $moduleUpdateAvailable = $false
        }
      }

      $moduleStatusText = if (-not $moduleInstalled) {
        'Not Installed'
      } elseif (-not $module.Enabled) {
        'Disabled'
      } elseif ($moduleUpdateAvailable) {
        'Update Available'
      } else {
        'Enabled'
      }

      [pscustomobject]@{
        PSTypeName          = 'PwshProfile.OptionalModule'
        Name                = $module.Name
        Description         = $module.Description
        Enabled             = [bool]$module.Enabled
        Installed           = $moduleInstalled
        ModuleVersion       = $moduleVersion
        BundleVersion       = $global:PwshProfileVersion
        LatestBundleVersion = $selectedRemoteVersion
        LatestModuleVersion = $latestModuleVersion
        UpdateAvailable     = $moduleUpdateAvailable
        Status              = $moduleStatusText
        Path                = $modulePath
      }
    }
  )

  $result = [pscustomobject]@{
    PSTypeName                = 'PwshProfile.Status'
    LocalVersion              = $global:PwshProfileVersion
    StableVersion             = if ($stableVersion) {
      $stableVersion
    } elseif ($SettingsOnly) {
      $null
    } elseif ($remoteQuerySucceeded) {
      'Not published'
    } else {
      'Unavailable'
    }
    PreviewVersion            = if ($previewVersion) {
      $previewVersion
    } elseif ($SettingsOnly) {
      $null
    } elseif ($remoteQuerySucceeded) {
      'Not published'
    } else {
      'Unavailable'
    }
    EnablePreReleaseUpdate    = $enablePreReleaseUpdate
    EnablePublicIP            = $enablePublicIP
    EnableNetworkCidr         = $enableNetworkCidr
    EnableEndOfLife           = $enableEndOfLife
    EnableAzureKubernetes     = $enableAzureKubernetes
    EnableDns                 = $enableDns
    EnableTlsCertificate      = $enableTlsCertificate
    UpdateChannel             = if ($enablePreReleaseUpdate) { 'prerelease' } else { 'stable' }
    OptionalModules           = $moduleStatuses
    EnabledModules            = @($moduleStatuses | Where-Object Enabled | Select-Object -ExpandProperty Name)
    DisabledModules           = @($moduleStatuses | Where-Object { -not $_.Enabled } | Select-Object -ExpandProperty Name)
    ModulesAvailableForUpdate = @($moduleStatuses | Where-Object UpdateAvailable | Select-Object -ExpandProperty Name)
    ConfigPath                = $configPath
  }

  if ($SettingsOnly) {
    return $result
  }

  $result | Format-List | Out-Host
  Write-Host 'Pwsh Profile Modules:'
  $moduleStatuses | Sort-Object -Property Name | Format-Table -AutoSize -Property @(
    @{ Label = 'Module'; Expression = { $_.Name -replace '^PwshProfile\.', '' } }
    @{ Label = 'Version'; Expression = { $_.ModuleVersion } }
    @{ Label = 'Description'; Expression = { $_.Description } }
    @{ Label = 'Status'; Expression = { $_.Status } }
  ) | Out-Host
}

function global:Set-PwshProfile {
  [CmdletBinding(DefaultParameterSetName = 'Status')]
  param (
    [Parameter(ParameterSetName = 'Stable')]
    [switch] $EnableReleaseUpdate,

    [Parameter(ParameterSetName = 'Preview')]
    [switch] $EnablePreReleaseUpdate,

    [Parameter(ParameterSetName = 'PublicIP')]
    [switch] $EnablePublicIP,

    [Parameter(ParameterSetName = 'NetworkCidr')]
    [switch] $EnableNetworkCidr,

    [Parameter(ParameterSetName = 'EndOfLife')]
    [switch] $EnableEndOfLife,

    [Parameter(ParameterSetName = 'AzureKubernetes')]
    [switch] $EnableAzureKubernetes,

    [Parameter(ParameterSetName = 'Dns')]
    [switch] $EnableDns,

    [Parameter(ParameterSetName = 'TlsCertificate')]
    [switch] $EnableTlsCertificate,

    [switch] $PassThru
  )

  if (-not $PSBoundParameters.ContainsKey('EnableReleaseUpdate') -and
    -not $PSBoundParameters.ContainsKey('EnablePreReleaseUpdate') -and
    -not $PSBoundParameters.ContainsKey('EnablePublicIP') -and
    -not $PSBoundParameters.ContainsKey('EnableNetworkCidr') -and
    -not $PSBoundParameters.ContainsKey('EnableEndOfLife') -and
    -not $PSBoundParameters.ContainsKey('EnableAzureKubernetes') -and
    -not $PSBoundParameters.ContainsKey('EnableDns') -and
    -not $PSBoundParameters.ContainsKey('EnableTlsCertificate')) {
    return Get-PwshProfile
  }

  $current = Get-PwshProfile -SettingsOnly
  $usePrerelease = [bool]$current.EnablePreReleaseUpdate
  $usePublicIP = [bool]$current.EnablePublicIP
  $useNetworkCidr = [bool]$current.EnableNetworkCidr
  $useEndOfLife = [bool]$current.EnableEndOfLife
  $useAzureKubernetes = [bool]$current.EnableAzureKubernetes
  $useDns = [bool]$current.EnableDns
  $useTlsCertificate = [bool]$current.EnableTlsCertificate
  $changedModuleName = $null
  $changedModuleEnabled = $false
  if ($PSBoundParameters.ContainsKey('EnableReleaseUpdate')) {
    $usePrerelease = $false
  } elseif ($PSBoundParameters.ContainsKey('EnablePreReleaseUpdate')) {
    $usePrerelease = [bool]$EnablePreReleaseUpdate
  } elseif ($PSBoundParameters.ContainsKey('EnablePublicIP')) {
    $usePublicIP = [bool]$EnablePublicIP
    $changedModuleName = 'PwshProfile.PublicIP'
    $changedModuleEnabled = $usePublicIP
  } elseif ($PSBoundParameters.ContainsKey('EnableNetworkCidr')) {
    $useNetworkCidr = [bool]$EnableNetworkCidr
    $changedModuleName = 'PwshProfile.NetworkCidr'
    $changedModuleEnabled = $useNetworkCidr
  } elseif ($PSBoundParameters.ContainsKey('EnableEndOfLife')) {
    $useEndOfLife = [bool]$EnableEndOfLife
    $changedModuleName = 'PwshProfile.EndOfLife'
    $changedModuleEnabled = $useEndOfLife
  } elseif ($PSBoundParameters.ContainsKey('EnableAzureKubernetes')) {
    $useAzureKubernetes = [bool]$EnableAzureKubernetes
    $changedModuleName = 'PwshProfile.AzureKubernetes'
    $changedModuleEnabled = $useAzureKubernetes
  } elseif ($PSBoundParameters.ContainsKey('EnableDns')) {
    $useDns = [bool]$EnableDns
    $changedModuleName = 'PwshProfile.Dns'
    $changedModuleEnabled = $useDns
  } else {
    $useTlsCertificate = [bool]$EnableTlsCertificate
    $changedModuleName = 'PwshProfile.TlsCertificate'
    $changedModuleEnabled = $useTlsCertificate
  }
  $configPath = $current.ConfigPath
  $configDirectory = Split-Path -Path $configPath -Parent
  if (-not (Test-Path -LiteralPath $configDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $configDirectory -Force -ErrorAction Stop | Out-Null
  }

  $settings = [ordered]@{
    schemaVersion          = 4
    enablePreReleaseUpdate = $usePrerelease
    enablePublicIP         = $usePublicIP
    enableNetworkCidr      = $useNetworkCidr
    enableEndOfLife        = $useEndOfLife
    enableAzureKubernetes  = $useAzureKubernetes
    enableDns              = $useDns
    enableTlsCertificate   = $useTlsCertificate
    updatedAt              = [DateTimeOffset]::UtcNow.ToString('o')
  }
  $temporaryPath = "$configPath.$PID.tmp"
  $backupPath = "$configPath.$PID.bak"
  $json = $settings | ConvertTo-Json -Depth 3
  try {
    [System.IO.File]::WriteAllText(
      [System.IO.Path]::GetFullPath($temporaryPath),
      "$json`n",
      [System.Text.UTF8Encoding]::new($false)
    )
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
      [System.IO.File]::Replace(
        [System.IO.Path]::GetFullPath($temporaryPath),
        [System.IO.Path]::GetFullPath($configPath),
        [System.IO.Path]::GetFullPath($backupPath),
        $true
      )
    } else {
      [System.IO.File]::Move(
        [System.IO.Path]::GetFullPath($temporaryPath),
        [System.IO.Path]::GetFullPath($configPath)
      )
    }
  } finally {
    Remove-Item -LiteralPath $temporaryPath, $backupPath -Force -ErrorAction Ignore
  }

  if ($PSBoundParameters.ContainsKey('EnableReleaseUpdate') -or
    $PSBoundParameters.ContainsKey('EnablePreReleaseUpdate')) {
    # Force the newly selected channel to be checked on the next profile load.
    Remove-Item -LiteralPath (Join-Path $env:APPDATA 'PwshProfile\update-state.json') `
      -Force -ErrorAction Ignore
    $channel = if ($usePrerelease) { 'prerelease' } else { 'stable' }
    Write-Host "Pwsh Profile OTA channel set to $channel. Reload the profile to start a fresh update check."
  } else {
    $moduleDisplayName = $changedModuleName -replace '^PwshProfile\.', ''
    if ($changedModuleEnabled) {
      $modulePath = Join-Path $env:APPDATA "PwshProfile\modules\$changedModuleName\$changedModuleName.psd1"
      if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
        Write-Warning "The enabled $changedModuleName module was not found: $modulePath. Run Update-PwshProfile to restore tracked assets."
      } else {
        try {
          Import-Module -Name $modulePath -Global -Force -ErrorAction Stop
          Write-Host "Pwsh Profile $moduleDisplayName module enabled and loaded."
        } catch {
          Write-Warning "Pwsh Profile $moduleDisplayName module was enabled but could not be loaded. $($_.Exception.Message)"
        }
      }
    } else {
      Remove-Module -Name $changedModuleName -Force -ErrorAction Ignore
      Write-Host "Pwsh Profile $moduleDisplayName module disabled and unloaded."
    }
  }

  if ($PassThru) {
    Get-PwshProfile
  }
}

function global:Get-PwshProfileVersion {
  [CmdletBinding()]
  param ()

  $statePath = Join-Path $env:APPDATA 'PwshProfile\update-state.json'
  $state = if (Test-Path -LiteralPath $statePath -PathType Leaf) {
    try {
      Get-Content -LiteralPath $statePath -Raw -ErrorAction Stop |
      ConvertFrom-Json -ErrorAction Stop
    } catch {
      $null
    }
  }

  $latestVersion = if ($state -and $state.latestVersion) { [string]$state.latestVersion } else { $null }
  $updateAvailable = $false
  if ($latestVersion) {
    try {
      $updateAvailable = (Compare-PwshProfileSemanticVersion `
          -Left $latestVersion `
          -Right $global:PwshProfileVersion) -gt 0
    } catch {
      $updateAvailable = $false
    }
  }

  [pscustomobject]@{
    CurrentVersion    = $global:PwshProfileVersion
    LatestVersion     = $latestVersion
    LatestTag         = if ($state) { $state.latestTag } else { $null }
    UpdateAvailable   = $updateAvailable
    CheckedChannel    = if ($state) { $state.channel } else { $null }
    ConfiguredChannel = (Get-PwshProfile -SettingsOnly).UpdateChannel
    LastChecked       = if ($state) { $state.checkedAt } else { $null }
    ReleaseUrl        = if ($state) { $state.releaseUrl } else { $null }
  }
}

function global:Update-PwshProfile {
  [CmdletBinding()]
  param (
    [switch] $Prerelease
  )

  $setupPath = Join-Path $env:APPDATA 'PwshProfile\functions\Invoke-PwshProfileSetup.ps1'
  if (-not (Test-Path -LiteralPath $setupPath -PathType Leaf)) {
    Write-Warning "The local profile updater was not found. Run Invoke-PwshProfileSetup.ps1 -RunPhase Profile once to install it."
    return
  }

  $usePrerelease = if ($PSBoundParameters.ContainsKey('Prerelease')) {
    [bool]$Prerelease
  } else {
    [bool](Get-PwshProfile -SettingsOnly).EnablePreReleaseUpdate
  }
  & $setupPath -RunPhase ProfileUpdate -Prerelease:$usePrerelease
}

function Import-PwshProfileModules {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object] $Settings
  )

  $optionalModules = @(
    [pscustomobject]@{
      Name    = 'PwshProfile.PublicIP'
      Enabled = [bool]$Settings.EnablePublicIP
    }
    [pscustomobject]@{
      Name    = 'PwshProfile.NetworkCidr'
      Enabled = [bool]$Settings.EnableNetworkCidr
    }
    [pscustomobject]@{
      Name    = 'PwshProfile.EndOfLife'
      Enabled = [bool]$Settings.EnableEndOfLife
    }
    [pscustomobject]@{
      Name    = 'PwshProfile.AzureKubernetes'
      Enabled = [bool]$Settings.EnableAzureKubernetes
    }
    [pscustomobject]@{
      Name    = 'PwshProfile.Dns'
      Enabled = [bool]$Settings.EnableDns
    }
    [pscustomobject]@{
      Name    = 'PwshProfile.TlsCertificate'
      Enabled = [bool]$Settings.EnableTlsCertificate
    }
  )
  foreach ($module in $optionalModules) {
    if (-not $module.Enabled) {
      Remove-Module -Name $module.Name -Force -ErrorAction Ignore
      continue
    }

    # Already loaded on a profile reload; skip the redundant reimport cost.
    if (Get-Module -Name $module.Name) { continue }

    $modulePath = Join-Path $script:PwshProfileStorePath "modules\$($module.Name)\$($module.Name).psd1"
    if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
      Write-Warning "The enabled $($module.Name) module was not found: $modulePath. Run Update-PwshProfile to restore tracked assets."
      continue
    }

    try {
      Import-Module -Name $modulePath -Global -ErrorAction Stop
    } catch {
      Write-Warning "Could not import the enabled $($module.Name) module. $($_.Exception.Message)"
    }
  }
}

function Start-PwshProfileUpdateCheck {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $StorePath,

    [Parameter(Mandatory)]
    [string] $Repository,

    [Parameter(Mandatory)]
    [string] $CurrentVersion,

    [switch] $Prerelease
  )

  $channel = if ($Prerelease) { 'prerelease' } else { 'stable' }
  $statePath = Join-Path $StorePath 'update-state.json'
  $state = if (Test-Path -LiteralPath $statePath -PathType Leaf) {
    try {
      Get-Content -LiteralPath $statePath -Raw -ErrorAction Stop |
      ConvertFrom-Json -ErrorAction Stop
    } catch {
      $null
    }
  }

  if ($state -and $state.channel -eq $channel -and $state.latestVersion) {
    try {
      if ((Compare-PwshProfileSemanticVersion `
            -Left ([string]$state.latestVersion) `
            -Right $CurrentVersion) -gt 0) {
        $latestTag = if ($state.latestTag) { [string]$state.latestTag } else { "v$($state.latestVersion)" }
        if ($Prerelease) {
          Write-Warning "Pwsh Profile [Pre Release] Update Available: $latestTag. Run Update-PwshProfile -Prerelease to install it."
        } else {
          Write-Warning "Pwsh Profile Update Available: $latestTag. Run Update-PwshProfile to install it."
        }
      }
    } catch {
      # Ignore invalid cached version data; the next check replaces it.
    }
  }

  if ($state -and $state.latestModules) {
    foreach ($moduleRelease in $state.latestModules.PSObject.Properties) {
      $moduleManifestPath = Join-Path $StorePath "modules\$($moduleRelease.Name)\$($moduleRelease.Name).psd1"
      if (-not (Test-Path -LiteralPath $moduleManifestPath -PathType Leaf)) { continue }
      try {
        $installedModuleVersion = [string](Import-PowerShellDataFile $moduleManifestPath).ModuleVersion
        if ((Compare-PwshProfileSemanticVersion -Left ([string]$moduleRelease.Value.version) -Right $installedModuleVersion) -gt 0) {
          Write-Warning "$($moduleRelease.Name) Update Available: $($moduleRelease.Value.tag). Run Update-PwshProfile to install it."
        }
      } catch {
        # Ignore invalid cached or installed module metadata.
      }
    }
  }

  $checkedAt = [DateTimeOffset]::MinValue
  if ($state -and $state.checkedAt) {
    [void][DateTimeOffset]::TryParse([string]$state.checkedAt, [ref]$checkedAt)
  }
  if ($state -and $state.channel -eq $channel -and
    [DateTimeOffset]::UtcNow - $checkedAt -lt [TimeSpan]::FromDays(1)) {
    return
  }

  if (-not [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
      [System.Runtime.InteropServices.OSPlatform]::Windows
    )) {
    return
  }

  if (-not (Test-Path -LiteralPath $StorePath -PathType Container)) {
    New-Item -ItemType Directory -Path $StorePath -Force -ErrorAction Ignore | Out-Null
  }

  $updateAttemptId = [guid]::NewGuid().ToString('n')
  $pendingState = [ordered]@{
    schemaVersion = 3
    updateAttemptId = $updateAttemptId
    channel       = $channel
    checkedAt     = [DateTimeOffset]::UtcNow.ToString('o')
    latestVersion = if ($state -and $state.channel -eq $channel) { $state.latestVersion } else { $null }
    latestTag     = if ($state -and $state.channel -eq $channel) { $state.latestTag } else { $null }
    releaseUrl    = if ($state -and $state.channel -eq $channel) { $state.releaseUrl } else { $null }
    latestModules = if ($state -and $state.latestModules) { $state.latestModules } else { [ordered]@{} }
    error         = $null
  }
  $pendingJson = $pendingState | ConvertTo-Json -Depth 3
  [System.IO.File]::WriteAllText($statePath, "$pendingJson`n", [System.Text.UTF8Encoding]::new($false))

  $escapedStatePath = $statePath.Replace("'", "''")
  $escapedRepository = $Repository.Replace("'", "''")
  $compareFunctionBody = ${function:global:Compare-PwshProfileSemanticVersion}.ToString()
  $checkTemplate = @'
function Compare-PwshProfileSemanticVersion {
__COMPARE_FUNCTION_BODY__
}

__RELEASE_PAGES_FUNCTION__

$statePath = '__STATE_PATH__'
$repository = '__REPOSITORY__'
$prerelease = [bool]::Parse('__PRERELEASE__')
$channel = if ($prerelease) { 'prerelease' } else { 'stable' }
$state = [ordered]@{
  schemaVersion = 3
  channel = $channel
  checkedAt = [DateTimeOffset]::UtcNow.ToString('o')
  latestVersion = $null
  latestTag = $null
  releaseUrl = $null
  latestModules = [ordered]@{}
  error = $null
}
try {
  $releases = Get-PwshProfileReleasePages -Uri "https://api.github.com/repos/$repository/releases?per_page=100" -Headers @{ 'User-Agent' = 'pwsh-profile-update-check' } -TimeoutSec 5 -ErrorAction Stop
  if ($prerelease) {
    $release = $null
    $selectedVersion = $null
    foreach ($candidate in @($releases | Where-Object { -not $_.draft -and $_.prerelease })) {
      if ([string]$candidate.tag_name -notmatch '^v(?<version>(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)-(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?)$') {
        continue
      }
      $candidateVersion = $Matches.version
      if (-not $release -or
        (Compare-PwshProfileSemanticVersion -Left $candidateVersion -Right $selectedVersion) -gt 0) {
        $release = $candidate
        $selectedVersion = $candidateVersion
      }
    }
  }
  else {
    $release = $null
    $selectedVersion = $null
    foreach ($candidate in @($releases | Where-Object { -not $_.draft -and -not $_.prerelease })) {
      if ([string]$candidate.tag_name -notmatch '^v(?<version>(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?)$') {
        continue
      }
      $candidateVersion = $Matches.version
      if (-not $release -or
        (Compare-PwshProfileSemanticVersion -Left $candidateVersion -Right $selectedVersion) -gt 0) {
        $release = $candidate
        $selectedVersion = $candidateVersion
      }
    }
  }

  if ($release) {
    $state.latestVersion = $selectedVersion
    $state.latestTag = [string]$release.tag_name
    $state.releaseUrl = [string]$release.html_url
  } else {
    $state.error = "No published $channel profile release is available."
  }
  foreach ($candidate in @($releases | Where-Object { -not $_.draft -and -not $_.prerelease })) {
    if ([string]$candidate.tag_name -notmatch '^(?<moduleName>PwshProfile\.[A-Za-z0-9_.-]+)-v(?<version>(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*))$') {
      continue
    }
    $moduleName = $Matches.moduleName
    $candidateVersion = $Matches.version
    $currentModule = $state.latestModules[$moduleName]
    if (-not $currentModule -or
      (Compare-PwshProfileSemanticVersion -Left $candidateVersion -Right $currentModule.version) -gt 0) {
      $state.latestModules[$moduleName] = [ordered]@{
        version = $candidateVersion
        tag = [string]$candidate.tag_name
      }
    }
  }
}
catch {
  $state.error = $_.Exception.Message
}
$json = $state | ConvertTo-Json -Depth 3
$temporaryPath = "$statePath.$PID.tmp"
[System.IO.File]::WriteAllText($temporaryPath, "$json`n", [System.Text.UTF8Encoding]::new($false))
Move-Item -LiteralPath $temporaryPath -Destination $statePath -Force
'@
  $checkScript = $checkTemplate.
  Replace('__COMPARE_FUNCTION_BODY__', $compareFunctionBody).
  Replace('__RELEASE_PAGES_FUNCTION__', ('function Get-PwshProfileReleasePages {' + ${function:global:Get-PwshProfileReleasePages}.ToString() + '}')).
  Replace('__STATE_PATH__', $escapedStatePath).
  Replace('__REPOSITORY__', $escapedRepository).
  Replace('__PRERELEASE__', ([bool]$Prerelease).ToString())

  $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($checkScript))
  $executable = if ($PSVersionTable.PSEdition -eq 'Core') {
    Join-Path $PSHOME 'pwsh.exe'
  } else {
    Join-Path $PSHOME 'powershell.exe'
  }

  try {
    Start-Process -FilePath $executable -ArgumentList @(
      '-NoLogo', '-NoProfile', '-NonInteractive', '-EncodedCommand', $encodedCommand
    ) -WindowStyle Hidden -ErrorAction Stop | Out-Null
  } catch {
    # Do not let a failed launch leave a fresh checkedAt value that suppresses
    # retries for a day. Only restore our own pending write; another profile
    # instance may already have replaced it with a completed result.
    try {
      $currentState = Get-Content -LiteralPath $statePath -Raw -ErrorAction Stop |
      ConvertFrom-Json -ErrorAction Stop
      if ([string]$currentState.updateAttemptId -eq $updateAttemptId) {
        if ($state) {
          $restoredJson = $state | ConvertTo-Json -Depth 3
          [System.IO.File]::WriteAllText($statePath, "$restoredJson`n", [System.Text.UTF8Encoding]::new($false))
        } else {
          Remove-Item -LiteralPath $statePath -Force -ErrorAction Ignore
        }
      }
    } catch {
      # Update checks must never delay or break profile startup.
    }
  }
}

#
#
# Oh My Posh

$ompThemePath = Join-Path $env:APPDATA 'PwshProfile\themes\quick-term-cloud.omp.json'
$terminalIconsDeferred = $false

if (Get-Command -Name oh-my-posh -ErrorAction Ignore) {
  if (Test-Path -LiteralPath $ompThemePath -PathType Leaf) {
    function global:Update-PwshProfilePoshTerminalWidth {
      try {
        $env:POSH_TERMINAL_WIDTH = [string]$Host.UI.RawUI.WindowSize.Width
      } catch {
        $env:POSH_TERMINAL_WIDTH = '0'
      }
    }

    # Seed the value for the first render.
    Update-PwshProfilePoshTerminalWidth
    oh-my-posh init pwsh --config $ompThemePath | Invoke-Expression

    function Install-PwshProfilePoshContext {
      param([System.Management.Automation.PSModuleInfo] $Module)

      # Install in the scope where OMP resolves its context hook. OMP captures
      # command status before calling it; wrapping prompt would overwrite $?.
      & $Module {
        if (-not (Get-Variable PwshProfilePreviousContext -Scope Script -ErrorAction Ignore)) {
          $script:PwshProfilePreviousContext = ${function:Set-PoshContext}
        }
        function script:Set-PoshContext {
          param($originalStatus)
          if ($script:PwshProfilePreviousContext) {
            & $script:PwshProfilePreviousContext $originalStatus
          }
          Update-PwshProfilePoshTerminalWidth
        }
      }
    }
    # Resolve the module owning the active prompt; a name lookup can return
    # stale instances after reloading the profile.
    $poshModule = (Get-Command prompt -CommandType Function -ErrorAction Ignore).Module
    if ($poshModule -and $poshModule.Name -ne 'oh-my-posh-core') { $poshModule = $null }
    if ($poshModule) {
      Install-PwshProfilePoshContext -Module $poshModule
    }

    function global:Update-PwshProfilePoshIdleLayout {
      # OnIdle runs on the PowerShell event loop, not on a background timer.
      # Keep all console editing on that thread and leave typed input alone.
      try {
        if (-not (Get-Module -Name Terminal-Icons)) {
          Import-Module -Name Terminal-Icons -ErrorAction SilentlyContinue
        }

        $width = $Host.UI.RawUI.WindowSize.Width
        if ($width -le 0 -or [string]$width -eq $env:POSH_TERMINAL_WIDTH) { return }

        $line = ''
        $cursor = 0
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        if ($line.Length -ne 0) { return }

        # Record the attempt before repainting so a host that cannot redraw
        # does not retry on every idle event. The normal prompt also updates it.
        $env:POSH_TERMINAL_WIDTH = [string]$width
        [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
      } catch {
        # Unsupported console hosts retain the normal next-prompt refresh.
      }
    }

    # Reloading the profile replaces only our subscription, not other idle hooks.
    Get-EventSubscriber -SourceIdentifier PowerShell.OnIdle -ErrorAction Ignore |
    Where-Object { $_.Action.Name -eq 'PwshProfile.PoshResize' } |
    ForEach-Object {
      Unregister-Event -SubscriptionId $_.SubscriptionId
      if ($_.Action) { Remove-Job -Job $_.Action -Force -ErrorAction Ignore }
    }
    if (Get-Command PSConsoleHostReadLine -ErrorAction Ignore) {
      $resizeJob = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -Action {
        Update-PwshProfilePoshIdleLayout
      }
      $resizeJob.Name = 'PwshProfile.PoshResize'
      $terminalIconsDeferred = $true
    }
  } else {
    Write-Warning "Oh My Posh theme was not found: $ompThemePath"
  }
} else {
  Write-Warning 'Oh My Posh was not found. Install it with: winget install JanDeDobbeleer.OhMyPosh'
}

if (-not $terminalIconsDeferred) {
  try {
    Import-Module -Name Terminal-Icons -ErrorAction Stop
  } catch {
    Write-Warning "Could not import 'Terminal-Icons'. Run the Profile setup phase to restore tracked modules."
  }
}

#
# Azure CLI tab completion
# https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest&tabs=azure-cli&pivots=winget#enable-tab-completion-in-powershell

function global:Invoke-PwshProfileCompletionProcess {
  param(
    [System.Diagnostics.ProcessStartInfo] $StartInfo,
    [ValidateRange(100, 5000)] [int] $TimeoutMilliseconds = 2000
  )

  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $StartInfo
  $started = $false
  try {
    $started = $process.Start()
    if (-not $started) { return $false }

    # Argcomplete writes candidates to its temporary file. Drain diagnostic
    # pipes concurrently so a full pipe cannot stall the child until timeout.
    $stdoutDrain = $process.StandardOutput.BaseStream.CopyToAsync([System.IO.Stream]::Null)
    $stderrDrain = $process.StandardError.BaseStream.CopyToAsync([System.IO.Stream]::Null)
    if (-not $process.WaitForExit($TimeoutMilliseconds)) { return $false }
    return $process.ExitCode -eq 0
  } catch {
    return $false
  } finally {
    if ($started) {
      try {
        if (-not $process.HasExited) {
          # az.cmd launches Python; stopping only cmd.exe leaves that child alive.
          $process.Kill($true)
          $null = $process.WaitForExit(200)
        }
      } catch {
        # The child may exit between HasExited and Kill.
      }
    }
    $process.Dispose()
  }
}

# Completion process arguments and process-tree cleanup require PowerShell 7.
# Windows PowerShell 5.1 retains the normal CLI without this custom completer.
if ($PSVersionTable.PSVersion.Major -ge 7 -and
  (Get-Command -Name Register-ArgumentCompleter -ErrorAction Ignore) -and
  (Get-Command -Name az -ErrorAction Ignore)) {
  Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $azCommand = Get-Command -Name az -ErrorAction Ignore
    if (-not $azCommand) {
      return
    }

    $completionFile = New-TemporaryFile
    try {
      $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
      $startInfo.UseShellExecute = $false
      $startInfo.RedirectStandardOutput = $true
      $startInfo.RedirectStandardError = $true
      $startInfo.CreateNoWindow = $true

      # az on Windows is usually a .cmd wrapper, which CreateProcess cannot
      # launch directly; route it through cmd.exe when needed.
      if ($azCommand.Source -match '\.(cmd|bat)$') {
        $startInfo.FileName = (Get-Command -Name cmd.exe).Source
        $startInfo.ArgumentList.Add('/d')
        $startInfo.ArgumentList.Add('/c')
        $startInfo.ArgumentList.Add($azCommand.Source)
      } else {
        $startInfo.FileName = $azCommand.Source
      }

      # Set completion-only variables on the CHILD process, never on this
      # PowerShell session. A slow or timed-out completion can then never leak
      # az's autocomplete state into later, real az invocations.
      $startInfo.EnvironmentVariables['ARGCOMPLETE_USE_TEMPFILES'] = '1'
      $startInfo.EnvironmentVariables['_ARGCOMPLETE_STDOUT_FILENAME'] = $completionFile.FullName
      $startInfo.EnvironmentVariables['COMP_LINE'] = $commandAst.ToString()
      $startInfo.EnvironmentVariables['COMP_POINT'] = [string]$cursorPosition
      $startInfo.EnvironmentVariables['_ARGCOMPLETE'] = '1'
      $startInfo.EnvironmentVariables['_ARGCOMPLETE_SUPPRESS_SPACE'] = '0'
      $startInfo.EnvironmentVariables['_ARGCOMPLETE_IFS'] = "`n"
      $startInfo.EnvironmentVariables['_ARGCOMPLETE_SHELL'] = 'powershell'

      # Ignore partial candidates on timeout or failure.
      if (-not (Invoke-PwshProfileCompletionProcess -StartInfo $startInfo)) { return }

      Get-Content -LiteralPath $completionFile.FullName -ErrorAction Ignore |
      Sort-Object -Unique |
      ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
      }
    } finally {
      Remove-Item -LiteralPath $completionFile.FullName -Force -ErrorAction Ignore
    }
  }
}

#
# Pwsh Profile status display formatting

# Format data is per-process; skip re-registering it on a profile reload.
if (-not (Get-FormatData -TypeName 'PwshProfile.Status' -ErrorAction Ignore)) {
  try {
    $statusFormatPath = Join-Path $env:TEMP 'PwshProfile.Status.Format.ps1xml'
    $statusFormatXml = @'
<Configuration>
  <ViewDefinitions>
    <View>
      <Name>PwshProfile.Status</Name>
      <ViewSelectedBy>
        <TypeName>PwshProfile.Status</TypeName>
      </ViewSelectedBy>
      <ListControl>
        <ListEntries>
          <ListEntry>
            <ListItems>
              <ListItem><PropertyName>LocalVersion</PropertyName></ListItem>
              <ListItem><PropertyName>StableVersion</PropertyName></ListItem>
              <ListItem><PropertyName>PreviewVersion</PropertyName></ListItem>
              <ListItem><PropertyName>UpdateChannel</PropertyName></ListItem>
              <ListItem><PropertyName>EnablePreReleaseUpdate</PropertyName></ListItem>
              <ListItem><PropertyName>ConfigPath</PropertyName></ListItem>
            </ListItems>
          </ListEntry>
        </ListEntries>
      </ListControl>
    </View>
    <View>
      <Name>PwshProfile.OptionalModule</Name>
      <ViewSelectedBy>
        <TypeName>PwshProfile.OptionalModule</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>
          <TableColumnHeader><Label>Module</Label><Width>22</Width></TableColumnHeader>
          <TableColumnHeader><Label>Version</Label><Width>10</Width></TableColumnHeader>
          <TableColumnHeader><Label>Description</Label><Width>42</Width></TableColumnHeader>
          <TableColumnHeader><Label>Status</Label></TableColumnHeader>
        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <TableColumnItems>
              <TableColumnItem><ScriptBlock>$_.Name -replace '^PwshProfile\.', ''</ScriptBlock></TableColumnItem>
              <TableColumnItem><PropertyName>ModuleVersion</PropertyName></TableColumnItem>
              <TableColumnItem><PropertyName>Description</PropertyName></TableColumnItem>
              <TableColumnItem><PropertyName>Status</PropertyName></TableColumnItem>
            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>
  </ViewDefinitions>
</Configuration>
'@
    [System.IO.File]::WriteAllText($statusFormatPath, $statusFormatXml, [System.Text.UTF8Encoding]::new($false))
    Update-FormatData -AppendPath $statusFormatPath -ErrorAction Stop
  } catch {
    Write-Warning "Could not load Pwsh Profile status display formatting. $($_.Exception.Message)"
  }
}

#
# Optional modules and OTA update check

$profileSettings = Get-PwshProfile -SettingsOnly
Import-PwshProfileModules -Settings $profileSettings
try {
  Start-PwshProfileUpdateCheck `
    -StorePath $script:PwshProfileStorePath `
    -Repository $script:PwshProfileRepository `
    -CurrentVersion $script:PwshProfileVersion `
    -Prerelease:$profileSettings.EnablePreReleaseUpdate
} catch {
  Write-Verbose "Optional profile update check failed: $($_.Exception.Message)"
}

Remove-Item Function:Import-PwshProfileModules -ErrorAction Ignore
Remove-Item Function:Start-PwshProfileUpdateCheck -ErrorAction Ignore
Remove-Variable -Name PwshProfileRepository, PwshProfileStorePath, profileSettings, statusFormatPath, statusFormatXml, terminalIconsDeferred -Scope Script -ErrorAction Ignore
