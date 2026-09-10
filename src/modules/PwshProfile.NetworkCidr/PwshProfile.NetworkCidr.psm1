function ConvertTo-NetworkCidrInteger {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [System.Net.IPAddress] $Address
  )

  $bytes = $Address.GetAddressBytes()
  ([uint64]$bytes[0] * 16777216) +
  ([uint64]$bytes[1] * 65536) +
  ([uint64]$bytes[2] * 256) +
  [uint64]$bytes[3]
}

function ConvertFrom-NetworkCidrInteger {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [ValidateRange(0, 4294967295)]
    [uint64] $Value
  )

  @(
    (($Value -shr 24) -band 255)
    (($Value -shr 16) -band 255)
    (($Value -shr 8) -band 255)
    ($Value -band 255)
  ) -join '.'
}

function Resolve-NetworkCidrProvider {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $Provider
  )

  switch ($Provider) {
    'Normal' { 'Standard' }
    'Amazon' { 'AWS' }
    'Google' { 'GCP' }
    default { $Provider }
  }
}

function New-NetworkCidrResult {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [uint64] $NetworkValue,

    [Parameter(Mandatory)]
    [ValidateRange(0, 32)]
    [int] $PrefixLength,

    [Parameter(Mandatory)]
    [ValidateSet('Standard', 'Azure', 'AWS', 'GCP')]
    [string] $Provider,

    [Parameter(Mandatory)]
    [string] $InputCidr,

    [Nullable[uint64]] $SubnetIndex,

    [Nullable[uint64]] $SubnetCount
  )

  $totalAddressCount = [uint64]1 -shl (32 - $PrefixLength)
  $lastValue = $NetworkValue + $totalAddressCount - 1
  $maskValue = if ($PrefixLength -eq 0) {
    [uint64]0
  }
  else {
    ([uint64]4294967295 -shl (32 - $PrefixLength)) -band [uint64]4294967295
  }
  $wildcardValue = [uint64]4294967295 -bxor $maskValue
  $reserved = @{}

  $addReservedAddress = {
    param(
      [uint64] $Value,
      [string] $Reason
    )

    if ($Value -lt $NetworkValue -or $Value -gt $lastValue) {
      return
    }

    $key = [string]$Value
    if (-not $reserved.ContainsKey($key)) {
      $reserved[$key] = [pscustomobject][ordered]@{
        Address = ConvertFrom-NetworkCidrInteger -Value $Value
        Reason = $Reason
      }
    }
  }

  $providerPrefixSupported = $true
  $providerPrefixConstraint = switch ($Provider) {
    'Azure' {
      $providerPrefixSupported = $PrefixLength -ge 2 -and $PrefixLength -le 29
      'Azure IPv4 address ranges must use a prefix from /2 through /29.'
    }
    'AWS' {
      $providerPrefixSupported = $PrefixLength -ge 16 -and $PrefixLength -le 28
      'AWS IPv4 VPC subnets must use a prefix from /16 through /28.'
    }
    'GCP' {
      $providerPrefixSupported = $PrefixLength -ge 4 -and $PrefixLength -le 29
      'GCP primary IPv4 subnet ranges must use a prefix from /4 through /29.'
    }
    default {
      'Standard IPv4 supports prefixes from /0 through /32.'
    }
  }

  switch ($Provider) {
    'Azure' {
      & $addReservedAddress $NetworkValue 'Network address'
      & $addReservedAddress ($NetworkValue + 1) 'Default gateway'
      & $addReservedAddress ($NetworkValue + 2) 'Azure DNS mapping'
      & $addReservedAddress ($NetworkValue + 3) 'Azure DNS mapping'
      & $addReservedAddress $lastValue 'Broadcast address'
    }
    'AWS' {
      & $addReservedAddress $NetworkValue 'Network address'
      & $addReservedAddress ($NetworkValue + 1) 'VPC router'
      & $addReservedAddress ($NetworkValue + 2) 'DNS server'
      & $addReservedAddress ($NetworkValue + 3) 'Reserved for future use'
      & $addReservedAddress $lastValue 'Network broadcast address'
    }
    'GCP' {
      & $addReservedAddress $NetworkValue 'Network address'
      & $addReservedAddress ($NetworkValue + 1) 'Default gateway'
      if ($lastValue -gt $NetworkValue) {
        & $addReservedAddress ($lastValue - 1) 'Reserved by Google Cloud'
      }
      & $addReservedAddress $lastValue 'Broadcast address'
    }
    default {
      if ($PrefixLength -le 30) {
        & $addReservedAddress $NetworkValue 'Network address'
        & $addReservedAddress $lastValue 'Broadcast address'
      }
    }
  }

  $reservedAddressCount = [uint64]$reserved.Count
  $usableAddressCount = $totalAddressCount - $reservedAddressCount
  $firstUsableValue = $null
  $lastUsableValue = $null
  if ($usableAddressCount -gt 0) {
    $candidate = $NetworkValue
    while ($reserved.ContainsKey([string]$candidate)) {
      $candidate++
    }
    $firstUsableValue = $candidate

    $candidate = $lastValue
    while ($reserved.ContainsKey([string]$candidate)) {
      $candidate--
    }
    $lastUsableValue = $candidate
  }

  $broadcastAddress = if ($Provider -ne 'Standard' -or $PrefixLength -le 30) {
    ConvertFrom-NetworkCidrInteger -Value $lastValue
  }
  else {
    $null
  }

  [pscustomobject][ordered]@{
    PSTypeName = 'PwshProfile.NetworkCidr.Result'
    InputCidr = $InputCidr
    Cidr = "$(ConvertFrom-NetworkCidrInteger -Value $NetworkValue)/$PrefixLength"
    Provider = $Provider
    PrefixLength = $PrefixLength
    SubnetMask = ConvertFrom-NetworkCidrInteger -Value $maskValue
    WildcardMask = ConvertFrom-NetworkCidrInteger -Value $wildcardValue
    NetworkAddress = ConvertFrom-NetworkCidrInteger -Value $NetworkValue
    FirstUsableIP = if ($null -ne $firstUsableValue) {
      ConvertFrom-NetworkCidrInteger -Value $firstUsableValue
    }
    else {
      $null
    }
    LastUsableIP = if ($null -ne $lastUsableValue) {
      ConvertFrom-NetworkCidrInteger -Value $lastUsableValue
    }
    else {
      $null
    }
    LastAddress = ConvertFrom-NetworkCidrInteger -Value $lastValue
    BroadcastAddress = $broadcastAddress
    TotalAddressCount = $totalAddressCount
    UsableAddressCount = $usableAddressCount
    ReservedAddressCount = $reservedAddressCount
    ReservedAddresses = @(
      $reserved.Keys |
        Sort-Object { [uint64]$_ } |
        ForEach-Object { $reserved[$_] }
    )
    ProviderPrefixSupported = $providerPrefixSupported
    ProviderPrefixConstraint = $providerPrefixConstraint
    SubnetIndex = $SubnetIndex
    SubnetCount = $SubnetCount
  }
}

function Get-NetworkCidr {
  <#
  .SYNOPSIS
      Calculates an IPv4 CIDR range using standard or cloud-provider reservations.

  .DESCRIPTION
      Returns reusable objects describing an IPv4 CIDR range. Provider-specific
      calculations model reserved subnet addresses for Azure, AWS, and GCP.
      Use -SplitPrefix or -SubnetCount to divide the input range into equal
      child subnets. Use -SubnetIndex to return one child without generating
      every subnet.

  .PARAMETER Cidr
      An IPv4 address and prefix length, such as 10.20.0.0/24. A host address is
      accepted and normalized to its containing network.

  .PARAMETER Provider
      The subnet reservation model. Standard is the default. Normal, Amazon, and
      Google are accepted as compatibility names for Standard, AWS, and GCP.

  .PARAMETER SplitPrefix
      A longer prefix used to return all equal child subnets within the input.

    .PARAMETER SubnetCount
      The minimum number of equal child subnets to create. The count is rounded
      up to the next power of two because CIDR subnets must be equally aligned.

    .PARAMETER SubnetIndex
      The zero-based index of one child subnet to return. Requires SplitPrefix
      or SubnetCount.

  .PARAMETER MaxSubnets
      Safety limit for the number of child subnet objects returned.

  .PARAMETER Summary
      Return only essential properties: InputCidr, Cidr, Provider, PrefixLength, SubnetMask,
      NetworkAddress, FirstUsableIP, LastUsableIP, BroadcastAddress, TotalAddressCount, and UsableAddressCount.

  .EXAMPLE
      Get-NetworkCidr -Cidr 10.20.0.15/24

  .EXAMPLE
      Get-NetworkCidr -Cidr 10.20.0.0/24 -Provider Azure | Format-List

  .EXAMPLE
      Get-NetworkCidr -Cidr 10.20.0.0/24 -Provider Azure -Summary

  .EXAMPLE
      Get-NetworkCidr 10.20.0.0/24 -Provider AWS -SplitPrefix 26

  .EXAMPLE
      Get-NetworkCidr 10.20.0.0/24 -SubnetCount 3

  .EXAMPLE
      Get-NetworkCidr 10.20.0.0/24 -SplitPrefix 28 -SubnetIndex 5
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [Alias('Network')]
    [ValidateNotNullOrEmpty()]
    [string] $Cidr,

    [ArgumentCompleter({
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
        @('Standard', 'Azure', 'AWS', 'GCP') | Where-Object { $_ -like "$wordToComplete*" }
      })]
    [string] $Provider = 'Standard',

    [ValidateRange(0, 32)]
    [int] $SplitPrefix,

    [ValidateRange(2, 4294967296)]
    [uint64] $SubnetCount,

    [ValidateRange(0, 4294967295)]
    [uint64] $SubnetIndex,

    [ValidateRange(1, 1048576)]
    [int] $MaxSubnets = 4096,

    [switch] $Summary
  )

  process {
    if ($Provider -notin @('Standard', 'Azure', 'AWS', 'GCP', 'Normal', 'Amazon', 'Google')) {
      throw "Provider '$Provider' is not supported. Use Standard, Azure, AWS, or GCP."
    }

    if ($Cidr -notmatch '^(?<address>[^/]+)/(?<prefix>\d{1,2})$') {
      throw "CIDR '$Cidr' must use IPv4 address/prefix notation, for example 10.20.0.0/24."
    }

    $address = $null
    if (-not [System.Net.IPAddress]::TryParse($Matches.address, [ref]$address) -or
      $address.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
      throw "CIDR '$Cidr' does not contain a valid IPv4 address."
    }

    $prefixLength = [int]$Matches.prefix
    if ($prefixLength -lt 0 -or $prefixLength -gt 32) {
      throw "CIDR '$Cidr' has an invalid IPv4 prefix length. Use /0 through /32."
    }

    $providerName = Resolve-NetworkCidrProvider -Provider $Provider
    $addressValue = ConvertTo-NetworkCidrInteger -Address $address
    $maskValue = if ($prefixLength -eq 0) {
      [uint64]0
    }
    else {
      ([uint64]4294967295 -shl (32 - $prefixLength)) -band [uint64]4294967295
    }
    $networkValue = $addressValue -band $maskValue

    $hasSplitPrefix = $PSBoundParameters.ContainsKey('SplitPrefix')
    $hasSubnetCount = $PSBoundParameters.ContainsKey('SubnetCount')
    $hasSubnetIndex = $PSBoundParameters.ContainsKey('SubnetIndex')

    if ($hasSplitPrefix -and $hasSubnetCount) {
      throw 'SplitPrefix and SubnetCount cannot be used together.'
    }

    if ($hasSubnetIndex -and -not ($hasSplitPrefix -or $hasSubnetCount)) {
      throw 'SubnetIndex requires SplitPrefix or SubnetCount.'
    }

    if (-not $hasSplitPrefix -and -not $hasSubnetCount) {
      $result = New-NetworkCidrResult `
        -NetworkValue $networkValue `
        -PrefixLength $prefixLength `
        -Provider $providerName `
        -InputCidr $Cidr

      if ($Summary) {
        $result | Select-Object InputCidr, Cidr, Provider, PrefixLength, SubnetMask, NetworkAddress, FirstUsableIP, LastUsableIP, BroadcastAddress, TotalAddressCount, UsableAddressCount
      }
      else {
        $result
      }
    }
    else {
      if ($hasSplitPrefix) {
        if ($SplitPrefix -le $prefixLength) {
          throw "SplitPrefix /$SplitPrefix must be longer than the input prefix /$prefixLength."
        }

        $childPrefix = $SplitPrefix
        $totalSubnetCount = [uint64]1 -shl ($childPrefix - $prefixLength)
      }
      else {
        $childPrefix = $prefixLength
        $totalSubnetCount = [uint64]1
        while ($totalSubnetCount -lt $SubnetCount -and $childPrefix -lt 32) {
          $childPrefix++
          $totalSubnetCount = $totalSubnetCount -shl 1
        }

        if ($totalSubnetCount -lt $SubnetCount) {
          throw "CIDR '$Cidr' cannot be divided into at least $SubnetCount IPv4 subnets."
        }
      }

      if ($hasSubnetIndex -and $SubnetIndex -ge $totalSubnetCount) {
        throw "SubnetIndex $SubnetIndex is outside the valid range 0 through $($totalSubnetCount - 1)."
      }

      if (-not $hasSubnetIndex -and $totalSubnetCount -gt $MaxSubnets) {
        throw "Splitting '$Cidr' into /$childPrefix produces $totalSubnetCount subnets, exceeding MaxSubnets $MaxSubnets."
      }

      $subnetSize = [uint64]1 -shl (32 - $childPrefix)
      $firstIndex = if ($hasSubnetIndex) { $SubnetIndex } else { [uint64]0 }
      $indexLimit = if ($hasSubnetIndex) { $SubnetIndex + 1 } else { $totalSubnetCount }
      for ([uint64]$index = $firstIndex; $index -lt $indexLimit; $index++) {
        $result = New-NetworkCidrResult `
          -NetworkValue ($networkValue + ($index * $subnetSize)) `
          -PrefixLength $childPrefix `
          -Provider $providerName `
          -InputCidr $Cidr `
          -SubnetIndex $index `
          -SubnetCount $totalSubnetCount

        if ($Summary) {
          $result | Select-Object InputCidr, Cidr, Provider, PrefixLength, SubnetMask, NetworkAddress, FirstUsableIP, LastUsableIP, BroadcastAddress, TotalAddressCount, UsableAddressCount
        }
        else {
          $result
        }
      }
    }
  }
}

Export-ModuleMember -Function Get-NetworkCidr
