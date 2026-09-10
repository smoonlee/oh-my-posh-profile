function Get-PublicIPHttpStatusCode {
  # Extracts the HTTP status code from an Invoke-RestMethod error, if present.
  param (
    [Parameter(Mandatory)]
    [System.Management.Automation.ErrorRecord] $ErrorRecord
  )

  $response = $ErrorRecord.Exception.Response
  if (-not $response) {
    return $null
  }

  try {
    return [int]$response.StatusCode
  }
  catch {
    return $null
  }
}

function Get-PublicIP {
  <#
  .SYNOPSIS
      Gets public IP and location information reported by ipinfo.io.

  .DESCRIPTION
      Queries ipinfo.io over HTTPS and returns an object containing the public
      IP address, hostname, ISP, city, region, and country.

    .PARAMETER TimeoutSec
      Maximum number of seconds to wait for the ipinfo.io request. The default
      is five seconds.

  .EXAMPLE
      Get-PublicIP

      Gets public IP information using the default five-second timeout.

  .EXAMPLE
      Get-PublicIP | Format-List

      Displays the returned public IP information as a list.
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param (
    [ValidateRange(1, 60)]
    [int] $TimeoutSec = 5
  )

  try {
    $ipInfo = Invoke-RestMethod `
      -Uri 'https://ipinfo.io' `
      -TimeoutSec $TimeoutSec `
      -ErrorAction Stop
  }
  catch {
    if ((Get-PublicIPHttpStatusCode -ErrorRecord $_) -eq 429) {
      throw 'ipinfo.io rate-limited this request (HTTP 429). Wait a minute before trying again.'
    }
    throw "Unable to retrieve public IP information from ipinfo.io. $($_.Exception.Message)"
  }

  $address = $null
  if (-not $ipInfo -or
    -not $ipInfo.ip -or
    -not [System.Net.IPAddress]::TryParse([string]$ipInfo.ip, [ref]$address)) {
    throw 'ipinfo.io returned an invalid IP address.'
  }

  [pscustomobject][ordered]@{
    'Public IP' = $address.ToString()
    'Host Name' = [string]$ipInfo.hostname
    'ISP' = [string]$ipInfo.org
    'City' = [string]$ipInfo.city
    'Region' = [string]$ipInfo.region
    'Country' = [string]$ipInfo.country
  }
}

Export-ModuleMember -Function Get-PublicIP
