<#
.SYNOPSIS
This PowerShell script is used to update and configure the PowerShell profile with Oh My Posh and other modules.

.DESCRIPTION
The script performs the following tasks:
- Retrieves the latest version of the Oh My Posh profile from a GitHub repository.
- Imports required PowerShell modules (Posh-Git, Terminal-Icons, PSReadLine).
- Configures PSReadLine options for enhanced command line editing.
- Checks if a profile update is available and displays a warning message if necessary.
- Loads the Oh My Posh application with a specified theme.
- Sets environment variables for Azure and Git integration.
- Defines functions for retrieving public IP address, Azure CLI tab completion, system uptime, Azure virtual machine system uptime, and more.
- Provides functions for updating the PowerShell profile, updating Windows applications, cleaning Git branches, and retrieving DNS record information.

.PARAMETER None
This script does not accept any parameters.

.EXAMPLE
.\Microsoft.PowerShell_profile.ps1
Runs the script to update and configure the PowerShell profile.

.NOTES
- This script requires an internet connection to retrieve the latest Oh My Posh profile from GitHub.
- Make sure to have the required PowerShell modules (Posh-Git, Terminal-Icons, PSReadLine) installed before running this script.
- The script assumes that the Oh My Posh theme file is located in the specified path: %LOCALAPPDATA%\Programs\oh-my-posh\themes.

Author: Simon Lee
Version: 3.0 - May 2024 | Mk3 Profile Script Created
Version: 3.1 - May 2024 | Updated Get-AzSystemUptime Function check Machine state [Running] [Offline]
Version: 3.1.1 - May 2024 | Updated updateVSCodePwshModule to check for source folder and return is missing
Version: 3.1.2 - May 2024 | Fixed PSReadLine Module Update for PowerShell 5, Moved code block to wrong location 🤦‍♂️
Version: 3.1.3 - May 2024 | Created Update-WindowsApps functions, Wrapper for winget upgrade --all --include-unknown --force
Version: 3.1.4 - May 2024 | Created Remove-GitBranch function, Wrapper for git branch -D and PSPROFILE reflow
Version: 3.1.5 - May 2024 | Corrected dateTime stamp for last reboot time in Get-SystemUptime Get-AzSystemUptime function
Version: 3.1.5.1 - May 2024 | Fix Type for Remove-GitBranch Function to remove '* main' and '* master'
Version: 3.1.6 - May 2024 | Fixed AzCLI AutoTab (added missing function back - https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli#enable-tab-completion-in-powershell)
Version: 3.1.7 - May 2024 | Fixed updateVSCodePwshModule, Renamed to patchVSCodePwshModule and updated FolderName to get only latest folder
Version: 3.1.8 - June 2024 | Adding Get-DnsResult Function
Version: 3.1.8.1 - June 2024 | Rename Get-PublicIPAddress to Get-MyPublicIP
Version: 3.1.9 - July 2024 | Created Get AKS Version Function
Version: 3.1.10 - July 2024 | Updated Remove-GitBranch Function (Code Clean Up with ChatGPT)
Version: 3.1.10.1 - July 2024 | Updated Remove-GitBranch Function (added defaultBranch parameter) + Code Formatting Clean Up
Version: 3.1.10.2 - July 2024 | Code Formatting Patch
Version: 3.1.10.3 - July 2024 | Updated Remove-GitBranch Function - Update Branch CleanUp - defaultBranch x main
Version: 3.1.11 - July 2024 | Created Update-PSProfile Function, Script Refactor and YAML Release Pipeline created for Profile Versioning
Version: 3.1.12 - July 2024 | YAML Release Pipeline for Profile Versioning, Added Profile Update Checker
Version: 3.1.12.1 - July 2024 | Minor Script Fixes, From Development to Production Repository
Version: 3.1.12.2 - July 2024 | Minor Script Fixes, From Development to Production Repository
Version: 3.1.12.3 - July 2024 | Minor Script Fixes, From Development to Production Repository
Version: 3.1.12.4 - July 2024 | Fixed Azure CLI Tab Completion Function
Version: 3.1.12.5 - July 2024 | Patched Update-PSProfile find and replace.
Version: 3.1.12.5.* - July 2024 | Patched Update-PSProfile find and replace.
Version: 3.1.13 - July 2024 | Update-PSProfile Function FIXED! 🥳
Version: 3.1.13.1 - July 2024 | Added Get-NetConfig Function
Version: 3.1.13.2 - July 2024 | Updated Get-NetConfig Function Formatting
Version: 3.1.14 - July 2024 | Get-NetConfig Function GA
Version: 3.1.14.1 - July 2024 | Updated Get-NetConfig with IP Class and Subnet Mask.
Version: 3.1.14.2 - July 2024 | Updated Update-WindowsApps, Required Administrator elevation to skip UAC.
Version: 3.1.14.3 - July 2024 | Updated Update-PSProfile, added Return Happy check if $profileVersion -match $profileRelease
Version: 3.1.14.4 - July 2024 | Updated Update-PSProfile, Changed Initial Function Write-Output to 'Checking for PSProfile Release.'
Version: 3.1.15 - July 2024 | Updated Get-NetConfig, Added CIDR Table Generation and showSubnet and IPv6 Support
#>

# Oh My Posh Profile Version
$profileVersion = '3.1.15.1-dev'

# GitHub Repository Details
$gitRepositoryUrl = "https://api.github.com/repos/smoonlee/oh-my-posh-profile/releases"
$newProfileReleaseTag = $(Invoke-RestMethod -Uri $gitRepositoryUrl/latest).tag_name
$newProfileReleaseUrl = $(Invoke-RestMethod -Uri $gitRepositoryUrl/latest).assets.browser_download_url

# Import PowerShell Modules
Import-Module -Name 'Posh-Git'
Import-Module -Name 'Terminal-Icons'
Import-Module -Name 'PSReadLine'

# PSReadLine Config
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -HistoryNoDuplicates:$True
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# Profile Update Checker
if ($profileVersion -ne $newProfileReleaseTag) {
    Write-Warning "[Oh My Posh] - Profile Update Available, Please run: Update-PSProfile"
}

# Load Oh My Posh Application
oh-my-posh init powershell --config "$env:POSH_THEMES_PATH\themeNameHere" | Invoke-Expression

# Local Oh-My-Posh Configuration
$env:POSH_AZURE_ENABLED = $true
$env:POSH_GIT_ENABLED = $true

# Function - Get Public IP Address
function Get-MyPublicIP {
    $ip = Invoke-WebRequest -Uri 'https://ifconfig.me/ip'
    $ip.Content
}

# Function - Azure CLI Tab Completion
Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    $completion_file = New-TemporaryFile
    $env:ARGCOMPLETE_USE_TEMPFILES = 1
    $env:_ARGCOMPLETE_STDOUT_FILENAME = $completion_file
    $env:COMP_LINE = $wordToComplete
    $env:COMP_POINT = $cursorPosition
    $env:_ARGCOMPLETE = 1
    $env:_ARGCOMPLETE_SUPPRESS_SPACE = 0
    $env:_ARGCOMPLETE_IFS = "`n"
    $env:_ARGCOMPLETE_SHELL = 'powershell'
    az 2>&1 | Out-Null
    Get-Content $completion_file | Sort-Object | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_)
    }
    Remove-Item $completion_file, Env:\_ARGCOMPLETE_STDOUT_FILENAME, Env:\ARGCOMPLETE_USE_TEMPFILES, Env:\COMP_LINE, Env:\COMP_POINT, Env:\_ARGCOMPLETE, Env:\_ARGCOMPLETE_SUPPRESS_SPACE, Env:\_ARGCOMPLETE_IFS, Env:\_ARGCOMPLETE_SHELL
}

# Function - Get System Uptime
function Get-SystemUptime {
    function ConvertToReadableTime {
        param (
            [int]$uptimeSeconds
        )
        $uptime = New-TimeSpan -Seconds $uptimeSeconds
        "{0} days, {1} hours, {2} minutes, {3} seconds" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds
    }

    # Get the hostname
    $hostname = [System.Net.Dns]::GetHostName()

    # Get the operating system information
    $operatingSystem = Get-CimInstance Win32_OperatingSystem

    # Get the uptime in seconds
    $uptimeSeconds = (Get-Date) - $operatingSystem.LastBootUpTime
    $uptimeSeconds = $uptimeSeconds.TotalSeconds

    # Convert uptime to a readable format
    $uptime = ConvertToReadableTime -uptimeSeconds $uptimeSeconds

    # Get the last reboot time
    $lastRebootTime = $operatingSystem.LastBootUpTime
    $lastRebootTime = $lastRebootTime.ToString("dd/MM/yyyy HH:mm:ss")

    # Display the results
    Write-Output "Hostname: $hostname"
    Write-Output "Uptime: $uptime"
    Write-Output "Last Reboot Time: $lastRebootTime"
}

# Function - Get Azure Virtual Machine System Uptime
function Get-AzSystemUptime {
    param (
        [string] $subscriptionId,
        [string] $resourceGroup,
        [string] $vmName
    )

    if ($subscriptionId) {
        Set-AzContext -SubscriptionId $subscriptionId | Out-Null
        $subFriendlyName = (Get-AzContext).Subscription.Name
        Write-Output "[Azure] :: Setting Azure Subscription to $subFriendlyName "
    }

    $vmState = (Get-AzVM -ResourceGroupName $resourceGroup -Name $vmName -Status).Statuses.DisplayStatus[1]
    if ($vmState -ne 'VM running') {
        Write-Warning "[Azure] :: $vmName is not running. Please start the VM and try again."
        return
    }

    $osType = (Get-AzVM -ResourceGroupName $resourceGroup -Name $vmName).StorageProfile.OsDisk.OsType

    if ($osType -eq 'Windows') {
        Write-Output "[Azure] :: Getting System Uptime for $vmName in $resourceGroup..."
        Write-Warning "This may take up to 35 seconds"
        $response = Invoke-AzVMRunCommand -ResourceGroupName $resourceGroup -Name $vmName -CommandId 'RunPowerShellScript' -ScriptString '

        function ConvertToReadableTime {
            param (
                [int]$uptimeSeconds
            )
            $uptime = New-TimeSpan -Seconds $uptimeSeconds
            "{0} days, {1} hours, {2} minutes, {3} seconds" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds
        }

        # Get the hostname
        $hostname = [System.Net.Dns]::GetHostName()

        # Get the operating system information
        $operatingSystem = Get-CimInstance Win32_OperatingSystem

        # Get the uptime in seconds
        $uptimeSeconds = (Get-Date) - $operatingSystem.LastBootUpTime
        $uptimeSeconds = $uptimeSeconds.TotalSeconds

        # Convert uptime to a readable format
        $uptime = ConvertToReadableTime -uptimeSeconds $uptimeSeconds

        # Get the last reboot time
        $lastRebootTime = $operatingSystem.LastBootUpTime
        $lastRebootTime = $lastRebootTime.ToString("dd/MM/yyyy HH:mm:ss")

        # Display the results
        Write-Output " " # Required for script spacing
        Write-Output "[Azure] :: Hostname: $hostname"
        Write-Output "[Azure] :: Uptime: $uptime"
        Write-Output "[Azure] :: Last Reboot Time: $lastRebootTime"
        '

        $response.Value[0].Message
    }

    if ($osType -eq 'Linux') {
        Write-Output "[Azure] :: Getting System Uptime for $vmName in $resourceGroup..."
        Write-Warning "This may take up to 35 seconds"
        $response = Invoke-AzVMRunCommand -ResourceGroupName $resourceGroup -Name $vmName -CommandId 'RunShellScript' -ScriptString '
        echo "[Azure] :: Hostname: $(hostname)"
        echo "[Azure] :: Uptime: $(uptime -p )"
        echo "[Azure] :: Last Reboot Time: $(uptime -s)"
        '

        $pattern = '\[stdout\]([\s\S]*?)\[stderr\]'
        if ($response.value[0].Message -match $pattern) {
            $stdoutText = $matches[1].Trim()
            Write-Output `r $stdoutText
        }
    }
}

# Function - Reload PowerShell Session, Keeping Windows Terminal running.
function Register-PSProfile {
    Clear-Host
    # https://stackoverflow.com/questions/11546069/refreshing-restarting-powershell-session-w-out-exiting
    Get-Process -Id $PID | Select-Object -ExpandProperty Path | ForEach-Object { Invoke-Command { & "$_" } -NoNewScope }
}

# Function - Download PSProfile [Prod] or [Dev] Release
function Get-PSProfileUpdate {
    param (
        [string] $profileRelease,
        [string] $profileDownloadUrl
    )

    Write-Output "Checking for PSProfile Release..." `r
    Write-Output "Current Profile Version: $profileVersion"
    Write-Output "New Profile Version: $profileRelease"

    # Check if the profile is already up to date
    if ($profileVersion -match $profileRelease) {
        Write-Output "" # Required for script spacing
        Write-Warning "[Oh My Posh] - PSProfile is already up to date!"
        return
    }

    # Get Current Pwsh Theme
    $pwshThemeName = Split-Path $env:POSH_THEME -Leaf

    Write-Output "Updating Profile..."
    # Download the new profile
    Invoke-WebRequest -Uri $profileDownloadUrl -OutFile $PROFILE

    # Read the profile content
    $pwshProfile = Get-Content -Path $PROFILE -Raw

    # Replace 'themeNameHere' with the current theme name, but only once
    [regex]$pattern = "themeNameHere"
    $pwshProfile = $pattern.replace($pwshProfile, $pwshThemeName , 1)

    # Write the updated content back to the profile
    $pwshProfile | Set-Content -Path $PROFILE -Force

    # Wait for a few seconds
    Start-Sleep -Seconds 4

    # Reload PowerShell Profile
    Register-PSProfile
}

# Function - Update PowerShell Profile
function Update-PSProfile {
    param (
        [switch] $devMode
    )

    if ($devMode) {
        Write-Warning "[Oh My Posh] - Development Build Profile Update!!"
        $newProfileReleases = Invoke-RestMethod -Uri $gitRepositoryUrl
        $newProfilePreRelease = $newProfileReleases | Where-Object { $_.prerelease -eq $true } | Sort-Object -Property published_at -Descending
        $newProfilePreReleaseTag = $newProfilePreRelease[0].tag_name
        $newProfilePreReleaseUrl = $newProfilePreRelease[0].assets.browser_download_url

        # Get Latest Profile Release
        Get-PSProfileUpdate -profileRelease $newProfilePreReleaseTag -profileDownloadUrl $newProfilePreReleaseUrl

        return
    }

    # Get Latest Profile Release
    Get-PSProfileUpdate -profileRelease $newProfileReleaseTag -profileDownloadUrl $newProfileReleaseUrl
}

# Function - Update WinGet Applications
function Update-WindowsApps {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole] "Administrator")) {
        Write-Warning "This function must be run as an administrator."
        return
    }

    Write-Output "Updating Windows Applications..." `r
    winget upgrade --include-unknown --all --silent --force
}

# Function - Clean Git Branches
function Remove-GitBranch {
    param (
        [string] $defaultBranch,
        [string] $branchName,
        [switch] $all
    )

    $allBranches = git branch | ForEach-Object { $_.Trim() }
    $allBranches = $allBranches -replace '^\* ', ''
    $allBranches = $allBranches | Where-Object { $_ -notmatch 'main' -and $_ -notmatch 'dev-main' -and $_ -notmatch 'master' }

    #
    if (([string]::IsNullOrEmpty($allBranches))) {
        Write-Output "" # Required for script spacing
        $defaultBranchName = $(git remote show origin | Select-String -Pattern 'HEAD branch:').ToString().Split(':')[-1].Trim()
        Write-Output "Default Branch: $defaultBranchName"
        Write-Warning "No additional branches found"

        return
    }

    # Remove all branches in repository
    if ($all) {
        Write-Output "" # Required for script spacing
        Write-Warning "This will remove all local branches in the repository!"
        Write-Output 'Press any key to continue...'
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

        Write-Output `r "[Git] :: Moving to main branch"
        if ($defaultBranch) {
            git checkout $defaultBranch
        }
        else {
            git checkout main
        }

        Write-Output `r "[Git] :: Starting Branch Cleanse"
        foreach ($branch in $allBranches) {
            git branch -D $branch
        }
    }
    else {
        # Remove specific branch
        git branch -D $branchName
    }
}

# Function - Get DNS Record Information
function Get-DnsResult {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('UNKNOWN', 'A_AAAA', 'A', 'NS', 'MD', 'MF', 'CNAME', 'SOA', 'MB', 'MG', 'MR', 'NULL', 'WKS', 'PTR', 'HINFO', 'MINFO', 'MX', 'TXT', 'RP', 'AFSDB', 'X25', 'ISDN', 'RT', 'AAAA', 'SRV', 'DNAME', 'OPT', 'DS', 'RRSIG', 'NSEC', 'DNSKEY', 'DHCID', 'NSEC3', 'NSEC3PARAM', 'ANY', 'ALL', 'WINS')]
        [string]$recordType,
        [Parameter(Mandatory = $true)]
        [string]$domain
    )

    Resolve-DnsName -Name $domain -Type $recordType
}

# Function - Get Azure Kubernetes Service Version
function Get-AksVersion {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("eastus", "eastus2", "southcentralus", "westus", "northcentralus",
            "westus2", "centralus", "westcentralus", "canadacentral", "canadaeast",
            "brazilsouth", "northeurope", "westeurope", "uksouth", "ukwest",
            "francecentral", "francesouth", "australiaeast", "australiasoutheast",
            "australiacentral", "australiacentral2", "centralindia", "southindia",
            "westindia", "japaneast", "japanwest", "koreacentral", "koreasouth",
            "southeastasia", "eastasia", "centraluseuap", "eastus2euap",
            "southafricanorth", "southafricawest", "uaenorth", "uaecentral",
            "switzerlandnorth", "switzerlandwest", "germanynorth", "germanywestcentral",
            "norwayeast", "norwaywest")]
        [string]$location
    )
    az aks get-versions --location $location --output table
}

# Function - Get Network Address Space
function Get-NetConfig {
    param (
        [string]$cidr,

        [switch]$showSubnets,

        [switch]$showIpv4CidrTable
    )

    # Load the System.Numerics assembly for BigInteger support
    Add-Type -AssemblyName 'System.Numerics'

    # Function to convert IPv4 address to integer
    function ConvertTo-IntIPv4 {
        param ($ip)
        $i = 0
        $ip.Split('.') | ForEach-Object { [int]$_ } | ForEach-Object { $_ -shl 8 * (3 - $i++) } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    }

    # Function to convert integer to IPv4 address
    function ConvertTo-IPv4 {
        param ($int)
        $bytes = 3..0 | ForEach-Object { ($int -shr 8 * $_) -band 255 }
        return ($bytes -join '.')
    }

    # Function to convert IPv6 address to BigInteger
    function ConvertTo-IntIPv6 {
        param ($ip)
        $ipAddr = [System.Net.IPAddress]::Parse($ip)
        $bytes = $ipAddr.GetAddressBytes()
        [Array]::Reverse($bytes)
        $int = [System.Numerics.BigInteger]::Zero
        $bytes | ForEach-Object { $int = ($int -shl 8) -bor $_ }
        return $int
    }

    # Function to convert BigInteger to IPv6 address
    function ConvertTo-IPv6 {
        param ($int)
        $bytes = New-Object 'System.Collections.Generic.List[byte]'
        for ($i = 0; $i -lt 16; $i++) {
            $bytes.Insert(0, [byte]($int -band 0xFF))
            $int = $int -shr 8
        }
        $ipAddr = [System.Net.IPAddress]::new($bytes.ToArray())
        return $ipAddr.ToString()
    }

    # Function to convert prefix length to IPv4 subnet mask
    function ConvertTo-SubnetMaskIPv4 {
        param ($prefix)
        $maskInt = ([math]::Pow(2, $prefix) - 1) * [math]::Pow(2, 32 - $prefix)
        ConvertTo-IPv4 -int $maskInt
    }

    # Function to convert prefix length to IPv6 subnet mask
    function ConvertTo-SubnetMaskIPv6 {
        param ($prefix)
        $maskInt = [System.Numerics.BigInteger]::Pow(2, 128) - [System.Numerics.BigInteger]::Pow(2, 128 - $prefix)
        ConvertTo-IPv6 -int $maskInt
    }

    # Function to determine IPv4 class
    function Get-IPv4Class {
        param ($ip)
        $firstOctet = [int]$ip.Split('.')[0]
        switch ($firstOctet) {
            { $_ -ge 1 -and $_ -le 126 } { return 'A' }
            { $_ -ge 128 -and $_ -le 191 } { return 'B' }
            { $_ -ge 192 -and $_ -le 223 } { return 'C' }
            default { return 'Unknown' }
        }
    }

    # Function to generate a CIDR table
    function New-CidrTable {
        param (
            [string]$baseIp,
            [int]$basePrefix
        )

        # Convert base IP to integer
        $baseInt = if ($baseIp.Contains(':')) {
            ConvertTo-IntIPv6 -ip $baseIp
        }
        else {
            ConvertTo-IntIPv4 -ip $baseIp
        }

        # Generate CIDR table
        $cidrTable = @()

        for ($prefix = $basePrefix; $prefix -le 32; $prefix++) {
            $subnetSize = [math]::Pow(2, (32 - $prefix))
            $networkInt = $baseInt -band (([math]::Pow(2, 32) - 1) - ([math]::Pow(2, 32 - $prefix) - 1))
            $subnetMask = ConvertTo-SubnetMaskIPv4 -prefix $prefix
            $totalHosts = [int]($subnetSize - 2)  # Remove leading zeros

            $cidrTable += [PSCustomObject]@{
                CIDR       = "$baseIp/$prefix"
                SubnetMask = $subnetMask
                TotalHosts = $totalHosts
            }
        }

        $cidrTable
    }

    # Extract base IP and prefix length
    $baseIP, $prefix = $cidr -split '/'
    $prefix = [int]$prefix

    # Determine if IP is IPv6 or IPv4
    $isIPv6 = $baseIP.Contains(':')

    if ($showIpv4CidrTable) {
        if ($isIPv6) {
            Write-Output "CIDR Table for IPv6 is not fully supported in this function."
        }
        else {
            # Generate CIDR table for IPv4
            New-CidrTable -baseIp $baseIP -basePrefix $prefix | Format-Table -AutoSize
        }
        return
    }

    if ($isIPv6) {
        # IPv6 logic
        $baseInt = ConvertTo-IntIPv6 -ip $baseIP
        $networkSize = [System.Numerics.BigInteger]::Pow(2, 128 - $prefix)
        $subnetMask = ([System.Numerics.BigInteger]::Pow(2, 128) - [System.Numerics.BigInteger]::Pow(2, 128 - $prefix))

        $networkInt = $baseInt -band $subnetMask

        if ($showSubnets) {
            # Show subnets within this range
            $subnetPrefix = 64  # Example prefix length for subnets
            $subnetSize = [System.Numerics.BigInteger]::Pow(2, 128 - $subnetPrefix)
            $subnetMask = ([System.Numerics.BigInteger]::Pow(2, 128) - [System.Numerics.BigInteger]::Pow(2, 128 - $subnetPrefix))

            $currentSubnetInt = $networkInt
            while ($currentSubnetInt -lt $networkInt + $networkSize) {
                $subnetStart = $currentSubnetInt
                $subnetEnd = [System.Numerics.BigInteger]::Min($currentSubnetInt + $subnetSize - 1, $networkInt + $networkSize - 1)

                if ($subnetEnd -gt $subnetStart) {
                    $subnetStartIP = ConvertTo-IPv6 -int $subnetStart
                    $subnetEndIP = ConvertTo-IPv6 -int $subnetEnd

                    Write-Output "Subnet: $subnetStartIP - $subnetEndIP"
                }

                $currentSubnetInt = $currentSubnetInt + $subnetSize
            }
        }
        else {
            # Output results
            [PSCustomObject]@{
                IPClass          = 'N/A'  # Class not applicable to IPv6
                CIDR             = $cidr
                NetworkAddress   = ConvertTo-IPv6 -int $networkInt
                FirstUsableIP    = ConvertTo-IPv6 -int ($networkInt + 1)
                LastUsableIP     = ConvertTo-IPv6 -int ($networkInt + $networkSize - 2)
                BroadcastAddress = ConvertTo-IPv6 -int ($networkInt + $networkSize - 1)
                UsableHostCount  = ($networkSize - 2).ToString()
                SubnetMask       = ConvertTo-SubnetMaskIPv6 -prefix $prefix
            }
        }
    }
    else {
        # IPv4 logic
        $baseInt = ConvertTo-IntIPv4 -ip $baseIP
        $networkSize = [math]::Pow(2, 32 - $prefix)
        $subnetMask = ([math]::Pow(2, 32) - [math]::Pow(2, 32 - $prefix))

        $networkInt = $baseInt -band $subnetMask

        if ($showSubnets) {
            # Show subnets within this range
            $subnetPrefix = 24  # Example prefix length for subnets
            $subnetSize = [math]::Pow(2, 32 - $subnetPrefix)
            $subnetMask = ([math]::Pow(2, 32) - [math]::Pow(2, 32 - $subnetPrefix))

            $currentSubnetInt = $networkInt
            while ($currentSubnetInt -lt $networkInt + $networkSize) {
                $subnetStart = $currentSubnetInt
                $subnetEnd = [math]::Min($currentSubnetInt + $subnetSize - 1, $networkInt + $networkSize - 1)

                if ($subnetEnd -gt $subnetStart) {
                    $subnetStartIP = ConvertTo-IPv4 -int ($subnetStart + 1)
                    $subnetEndIP = ConvertTo-IPv4 -int ($subnetEnd - 1)

                    Write-Output "Subnet: $subnetStartIP - $subnetEndIP"
                }

                $currentSubnetInt = $currentSubnetInt + $subnetSize
            }
        }
        else {
            # Output results
            [PSCustomObject]@{
                IPClass          = Get-IPv4Class -ip $baseIP
                CIDR             = $cidr
                NetworkAddress   = ConvertTo-IPv4 -int $networkInt
                FirstUsableIP    = ConvertTo-IPv4 -int ($networkInt + 1)
                LastUsableIP     = ConvertTo-IPv4 -int ($networkInt + $networkSize - 2)
                BroadcastAddress = ConvertTo-IPv4 -int ($networkInt + $networkSize - 1)
                UsableHostCount  = ($networkSize - 2).ToString()
                SubnetMask       = ConvertTo-SubnetMaskIPv4 -prefix $prefix
            }
        }
    }
}
