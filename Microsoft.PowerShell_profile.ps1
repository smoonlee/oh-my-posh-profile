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
Version: 3.1.15.1 - July 2024 | Updated Get-NetConfig, Added CIDR Table Generation and showSubnet and IPv6 Support (Small fixes)
version: 3.1.16 - August 2024 | Created Get-EolInfo Function for End of Life Information https://endoflife.date/
Version: 3.1.16.1 - August 2024 | Created Get-PSProfileVersion Function to check latest release version
Version: 3.1.16.2 - August 2024 | Created Get-PSProfileTheme
Version: 3.1.16.3 - August 2024 | Updated Get-PSProfileVersion and Update-PSProfile to show change log
Version: 3.1.16.4 - August 2024 | Fixed Update-PSProfile to show change log
Version: 3.1.16.5 - August 2024 | Verbose Formatting for Change Log
Version: 3.1.16.6 - August 2024 | Verbose Formatting for Change Log
Version: 3.1.17 - August 2024 | GitHub Action Bump - No change made to profile
Version: 3.1.18 - August 2024 | Created Get-AzVMQuotaCheck
Version: 3.1.18.1 - August 2024 | Code Tidy and Get-AzVMQuotaCheck released
Version: 3.1.18.2 - August 2024 | Updated Get-AzVMQuotaCheck Logic
Version: 3.1.18.3 - August 2024 | Added aksReleaseCalendar switch to Get-AksVersion function
Version: 3.1.18.4 - August 2024 | Small formatting change to Update-WindowsApps function.
#>

# Oh My Posh Profile Version
$profileVersion = '3.1.18.4-prod'

# GitHub Repository Details
$gitRepositoryUrl = "https://api.github.com/repos/smoonlee/oh-my-posh-profile/releases"
$newProfileReleaseTag = $(Invoke-RestMethod -Uri $gitRepositoryUrl/latest).tag_name
$newProfileReleaseUrl = $(Invoke-RestMethod -Uri $gitRepositoryUrl/latest).assets.browser_download_url
$newProfileReleaseNotes = $(Invoke-RestMethod -Uri $gitRepositoryUrl/latest).body

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

# Function - Get PowerShell Profile Theme
function Get-PSProfileTheme {
    Write-Output "Current Theme: $env:POSH_THEME "
}

# Function - Get PowerShell Profile Version
function Get-PSProfileVersion {
    $newProfileReleases = Invoke-RestMethod -Uri $gitRepositoryUrl
    $newProfileStableRelease = $newProfileReleases | Where-Object { $_.prerelease -eq $false } | Sort-Object -Property published_at -Descending
    $newProfileDevRelease = $newProfileReleases | Where-Object { $_.prerelease -eq $true } | Sort-Object -Property published_at -Descending
    $newProfileReleaseTag = $newProfileStableRelease[0].tag_name
    $newProfileDevReleaseTag = $newProfileDevRelease[0].tag_name

    Write-Output "Current Local Profile Version: $profileVersion" `r
    Write-Output "Latest Stable Profile Release: $newProfileReleaseTag"
    Write-Output "Latest Dev Profile Release: $newProfileDevReleaseTag"
}

# Function - Download PSProfile [Prod] or [Dev] Release
function Get-PSProfileUpdate {
    param (
        [string] $profileRelease,
        [string] $profileReleaseNotes,
        [string] $profileDownloadUrl,
        [string] $profileVersion
    )

    Write-Output "Checking for PSProfile Release..." `r
    Write-Output "Current Profile Version: $profileVersion"
    Write-Output "New Profile Version: $profileRelease"
    Write-Output `r "PSProfile Change Log [$profileRelease]:"
    Write-Output "$profileReleaseNotes"

    # Check if the profile is already up to date
    if ($profileVersion -match $profileRelease) {
        Write-Output "" # Required for script spacing
        Write-Warning "[Oh My Posh] - PSProfile is already up to date!"
        return
    }

    # Get Current Pwsh Theme
    $pwshThemeName = Split-Path $env:POSH_THEME -Leaf

    Write-Output `r "Updating Profile..."
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
        [switch] $devMode,
        [switch] $force
    )

    if ($devMode) {
        Write-Warning "[Oh My Posh] - Development Build Profile Update!!"
        $newProfileReleases = Invoke-RestMethod -Uri $gitRepositoryUrl
        $newProfilePreRelease = $newProfileReleases | Where-Object { $_.prerelease -eq $true } | Sort-Object -Property published_at -Descending
        $newProfilePreReleaseTag = $newProfilePreRelease[0].tag_name
        $newProfilePreReleaseReleaseNotes = $newProfilePreRelease[0].body
        $newProfilePreReleaseUrl = $newProfilePreRelease[0].assets.browser_download_url

        # Get Latest Profile Release
        Get-PSProfileUpdate -profileRelease $newProfilePreReleaseTag -profileDownloadUrl $newProfilePreReleaseUrl -profileReleaseNotes $newProfilePreReleaseReleaseNotes

        return
    }

    

    # Get Latest Profile Release
    Get-PSProfileUpdate -profileRelease $newProfileReleaseTag -profileDownloadUrl $newProfileReleaseUrl -profileReleaseNotes $newProfileReleaseNotes
}

# Function - Update WinGet Applications
function Update-WindowsApps {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole] "Administrator")) {
        Write-Warning "This function must be run as an administrator."
        return
    }

    Write-Output `r "Updating Windows Applications..." `r
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
        [Parameter(Mandatory = $false)]
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
        [string]$location,
        [switch]$aksReleaseCalendar
    )

    if ($aksReleaseCalendar) {
        Start-Process "https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli#aks-kubernetes-release-calendar"
        return
    }

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

# Function - Get End of Life Information
function Get-EolInfo {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet(
            'akeneo-pim', 'alibaba-dragonwell', 'almalinux', 'alpine', 'amazon-cdk', 'amazon-corretto',
            'amazon-eks', 'amazon-glue', 'amazon-linux', 'amazon-neptune', 'amazon-rds-mariadb',
            'amazon-rds-mysql', 'amazon-rds-postgresql', 'android', 'angular', 'angularjs', 'ansible',
            'ansible-core', 'antix', 'apache', 'apache-activemq', 'apache-airflow', 'apache-apisix',
            'apache-camel', 'apache-cassandra', 'apache-flink', 'apache-groovy', 'apache-hadoop',
            'apache-hop', 'apache-kafka', 'apache-lucene', 'apache-spark', 'apache-struts',
            'api-platform', 'apple-watch', 'arangodb', 'argo-cd', 'artifactory', 'aws-lambda',
            'azul-zulu', 'azure-devops-server', 'azure-kubernetes-service', 'bazel', 'beats',
            'bellsoft-liberica', 'blender', 'bootstrap', 'bun', 'cakephp', 'calico', 'centos',
            'centos-stream', 'centreon', 'cert-manager', 'cfengine', 'chef-infra-client',
            'chef-infra-server', 'citrix-vad', 'ckeditor', 'clamav', 'cockroachdb', 'coder',
            'coldfusion', 'composer', 'confluence', 'consul', 'containerd', 'contao', 'contour',
            'cortex-xdr', 'cos', 'couchbase-server', 'craft-cms', 'dbt-core', 'dce', 'debian',
            'dependency-track', 'devuan', 'django', 'docker-engine', 'dotnet', 'dotnetfx',
            'drupal', 'drush', 'eclipse-jetty', 'eclipse-temurin', 'elasticsearch', 'electron',
            'elixir', 'emberjs', 'envoy', 'erlang', 'esxi', 'etcd', 'eurolinux', 'exim',
            'fairphone', 'fedora', 'ffmpeg', 'filemaker', 'firefox', 'fluent-bit', 'flux',
            'fortios', 'freebsd', 'gerrit', 'gitlab', 'go', 'goaccess', 'godot', 'google-kubernetes-engine',
            'google-nexus', 'gorilla', 'graalvm', 'gradle', 'grafana', 'grafana-loki', 'grails',
            'graylog', 'gstreamer', 'haproxy', 'harbor', 'hashicorp-vault', 'hbase', 'horizon',
            'ibm-aix', 'ibm-i', 'ibm-semeru-runtime', 'icinga', 'icinga-web', 'intel-processors',
            'internet-explorer', 'ionic', 'ios', 'ipad', 'ipados', 'iphone', 'isc-dhcp', 'istio',
            'jekyll', 'jenkins', 'jhipster', 'jira-software', 'joomla', 'jquery', 'jreleaser',
            'kde-plasma', 'keda', 'keycloak', 'kibana', 'kindle', 'kirby', 'kong-gateway',
            'kotlin', 'kubernetes', 'kubernetes-csi-node-driver-registrar', 'kubernetes-node-feature-discovery',
            'kuma', 'kyverno', 'laravel', 'libreoffice', 'lineageos', 'linux', 'linuxmint',
            'log4j', 'logstash', 'looker', 'lua', 'macos', 'mageia', 'magento', 'mariadb',
            'mastodon', 'matomo', 'mattermost', 'mautic', 'maven', 'mediawiki', 'meilisearch',
            'memcached', 'micronaut', 'microsoft-build-of-openjdk', 'mongodb', 'moodle',
            'motorola-mobility', 'msexchange', 'mssqlserver', 'mulesoft-runtime', 'mxlinux',
            'mysql', 'neo4j', 'neos', 'netbsd', 'nextcloud', 'nextjs', 'nexus', 'nginx',
            'nix', 'nixos', 'nodejs', 'nokia', 'nomad', 'numpy', 'nutanix-aos', 'nutanix-files',
            'nutanix-prism', 'nuxt', 'nvidia', 'nvidia-gpu', 'office', 'oneplus', 'openbsd',
            'openjdk-builds-from-oracle', 'opensearch', 'openssl', 'opensuse', 'opentofu',
            'openvpn', 'openwrt', 'openzfs', 'opnsense', 'oracle-apex', 'oracle-database',
            'oracle-jdk', 'oracle-linux', 'oracle-solaris', 'ovirt', 'pangp', 'panos', 'pci-dss',
            'perl', 'photon', 'php', 'phpbb', 'phpmyadmin', 'pixel', 'plesk', 'pnpm',
            'pop-os', 'postfix', 'postgresql', 'postmarketos', 'powershell', 'privatebin',
            'prometheus', 'protractor', 'proxmox-ve', 'puppet', 'python', 'qt', 'quarkus-framework',
            'quasar', 'rabbitmq', 'rails', 'rancher', 'raspberry-pi', 'react', 'react-native',
            'readynas', 'red-hat-openshift', 'redhat-build-of-openjdk', 'redhat-jboss-eap',
            'redhat-satellite', 'redis', 'redmine', 'rhel', 'robo', 'rocket-chat', 'rocky-linux',
            'ros', 'ros-2', 'roundcube', 'ruby', 'rust', 'salt', 'samsung-mobile', 'sapmachine',
            'scala', 'sharepoint', 'shopware', 'silverstripe', 'slackware', 'sles', 'solr',
            'sonar', 'sourcegraph', 'splunk', 'spring-boot', 'spring-framework', 'sqlite',
            'squid', 'steamos', 'surface', 'suse-manager', 'symfony', 'tails', 'tarantool',
            'telegraf', 'terraform', 'tomcat', 'traefik', 'twig', 'typo3', 'ubuntu', 'umbraco',
            'unity', 'unrealircd', 'varnish', 'vcenter', 'veeam-backup-and-replication',
            'visionos', 'visual-cobol', 'visual-studio', 'vmware-cloud-foundation',
            'vmware-harbor-registry', 'vmware-srm', 'vue', 'vuetify', 'wagtail', 'watchos',
            'weechat', 'windows', 'windows-embedded', 'windows-nano-server', 'windows-server',
            'windows-server-core', 'wireshark', 'wordpress', 'xcp-ng', 'yarn', 'yocto',
            'zabbix', 'zerto', 'zookeeper'
        )]
        [string]$productName,

        [Parameter()]
        [switch]$activeSupport,

        [Parameter()]
        [switch]$ltsSupport
    )

    $eolUrl = "https://endoflife.date/api/$productName"
    $eolInfo = Invoke-RestMethod -Uri $eolUrl

    # Get the current date
    $currentDate = Get-Date

    # Apply filtering based on parameters
    if ($ltsSupport) {
        # Filter only LTS versions
        $eolInfo = $eolInfo | Where-Object { $_.Lts -eq $true }
    }

    if ($activeSupport) {
        # Filter out versions that have reached EOL on or before the current date
        $eolInfo = $eolInfo | Where-Object { [DateTime]$_.eol -gt $currentDate }
    }

    $eolInfo
}

# Function - Get-VMQuotaCheck# Function - Get-VMQuotaCheck
function Get-AzVMQuotaCheck {
    param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Enter the Azure location")]
        [ValidateSet(
            "eastus", "eastus2", "westus", "westus2", "centralus", "northcentralus",
            "southcentralus", "westcentralus", "canadaeast", "canadacentral",
            "brazilsouth", "uksouth", "ukwest", "westeurope", "northeurope",
            "francecentral", "francesouth", "germanywestcentral", "germanynorth",
            "germanyeast", "switzerlandnorth", "switzerlandwest", "norwaywest",
            "norwayeast", "swedencentral", "swedensouth", "australiaeast",
            "australiasoutheast", "australiacentral", "australiacentral2",
            "japaneast", "japanwest", "koreacentral", "koreasouth", "centralindia",
            "southindia", "westindia", "uaenorth", "uaesouth", "southafricanorth",
            "southafricawest", "israelcentral", "israelnorth", "eastasia", "southeastasia",
            "hongkong", "mideast", "southamericaeast", "southamericawest", "singapore",
            "qatarcentral", "qatarnorth"
        )]
        [string]$location,

        [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Enter the VM size")]
        [ValidateSet(
            "Standard_A0", "Standard_A1", "Standard_A1_v2", "Standard_A2", "Standard_A2_v2", "Standard_A2m_v2",
            "Standard_A3", "Standard_A4", "Standard_A4_v2", "Standard_A4m_v2", "Standard_A5", "Standard_A6", "Standard_A7",
            "Standard_A8", "Standard_A8_v2", "Standard_A8m_v2", "Standard_A9", "Standard_B1ms", "Standard_B1s",
            "Standard_B2ms", "Standard_B2s", "Standard_B4ms", "Standard_B8ms", "Standard_D1", "Standard_D1_v2",
            "Standard_D2", "Standard_D2_v2", "Standard_D2_v3", "Standard_D2_v4", "Standard_D3", "Standard_D3_v2",
            "Standard_D4", "Standard_D4_v2", "Standard_D4_v3", "Standard_D4_v4", "Standard_D5_v2", "Standard_D8_v3",
            "Standard_D8_v4", "Standard_D11_v2", "Standard_D12_v2", "Standard_D12_v3", "Standard_D13_v2",
            "Standard_D13_v3", "Standard_D14_v2", "Standard_D14_v3", "Standard_D15_v2", "Standard_D16_v3",
            "Standard_D16_v4", "Standard_D32_v3", "Standard_D32_v4", "Standard_D48_v3", "Standard_D48_v4",
            "Standard_D64_v3", "Standard_D64_v4", "Standard_D96_v3", "Standard_DS1", "Standard_DS1_v2", "Standard_DS2",
            "Standard_DS2_v2", "Standard_DS3", "Standard_DS3_v2", "Standard_DS4", "Standard_DS4_v2", "Standard_DS5",
            "Standard_DS11_v2", "Standard_DS12_v2", "Standard_DS13_v2", "Standard_DS14_v2", "Standard_E2_v3",
            "Standard_E2_v4", "Standard_E2s_v3", "Standard_E2s_v4", "Standard_E4_v3", "Standard_E4_v4",
            "Standard_E4s_v3", "Standard_E4s_v4", "Standard_E8_v3", "Standard_E8_v4", "Standard_E8s_v3",
            "Standard_E8s_v4", "Standard_E16_v3", "Standard_E16_v4", "Standard_E16s_v3", "Standard_E16s_v4",
            "Standard_E20_v3", "Standard_E20s_v3", "Standard_E32_v3", "Standard_E32_v4", "Standard_E32s_v3",
            "Standard_E32s_v4", "Standard_E48_v3", "Standard_E48_v4", "Standard_E48s_v3", "Standard_E48s_v4",
            "Standard_E64_v3", "Standard_E64_v4", "Standard_E64i_v3", "Standard_E64i_v4", "Standard_E64is_v3",
            "Standard_E64is_v4", "Standard_E64s_v3", "Standard_E64s_v4", "Standard_E80_v3", "Standard_E80s_v3",
            "Standard_E104i_v5", "Standard_E104is_v5", "Standard_E104s_v5", "Standard_E112i_v5", "Standard_E112is_v5",
            "Standard_E112s_v5", "Standard_F1", "Standard_F2", "Standard_F2s", "Standard_F4", "Standard_F4s",
            "Standard_F8", "Standard_F8s", "Standard_F16", "Standard_F16s", "Standard_F32s", "Standard_F48s",
            "Standard_F64s", "Standard_F72s", "Standard_G1", "Standard_G2", "Standard_G3", "Standard_G4",
            "Standard_G5", "Standard_GS1", "Standard_GS2", "Standard_GS3", "Standard_GS4", "Standard_GS5",
            "Standard_H8", "Standard_H8m", "Standard_H16", "Standard_H16m", "Standard_H16mr", "Standard_H16r",
            "Standard_HB120-96rs_v3", "Standard_HB120rs_v3", "Standard_HC44rs", "Standard_L4", "Standard_L8",
            "Standard_L8s", "Standard_L16", "Standard_L16s", "Standard_L32s", "Standard_L48s", "Standard_L64s",
            "Standard_L80s", "Standard_M8ms", "Standard_M8", "Standard_M16ms", "Standard_M16", "Standard_M32ls",
            "Standard_M32ms", "Standard_M32ts", "Standard_M32", "Standard_M64ls", "Standard_M64ms",
            "Standard_M64s", "Standard_M64", "Standard_M128", "Standard_M128ms", "Standard_M128s",
            "Standard_NC6", "Standard_NC6s_v2", "Standard_NC6s_v3", "Standard_NC12", "Standard_NC12s_v2",
            "Standard_NC12s_v3", "Standard_NC24", "Standard_NC24r", "Standard_NC24rs_v2", "Standard_NC24rs_v3",
            "Standard_NC24s_v2", "Standard_NC24s_v3", "Standard_ND6", "Standard_ND6s", "Standard_ND12",
            "Standard_ND12s", "Standard_ND24rs", "Standard_ND24", "Standard_ND40rs_v2", "Standard_ND96asr_v4",
            "Standard_ND96amsr_A100_v4", "Standard_ND96asr_A100_v4", "Standard_NV6", "Standard_NV12",
            "Standard_NV24", "Standard_NV12s_v3", "Standard_NV24s_v3", "Standard_NV48s_v3", "Standard_NV4as_v4",
            "Standard_NV8as_v4", "Standard_NV16as_v4", "Standard_NV32as_v4", "Standard_NV48as_v4", "Standard_NV56as_v4",
            "Standard_NV72as_v4"
        )]
        [string]$skuType,

        [Parameter(Mandatory = $false, Position = 3, HelpMessage = "Enter the subscription ID")]
        [string]$subscriptionId
    )

    if ($subscriptionId) {

        # List all subscriptions
        $subscriptions = az account list --output json --only-show-errors  | ConvertFrom-Json
        $tenantFriendlyName = az account show --query 'tenantDisplayName' -o tsv

        # Check if the provided subscriptionId exists in the list of subscriptions
        if ($subscriptions | Where-Object { $_.id -eq $subscriptionId }) {
            $subscriptionExists = $true
            az account set --subscription $subscriptionId
        }

        if (!$subscriptionExists) {
            Write-Output " > Subscription $subscriptionId not found under $tenantFriendlyName Environment."
            Write-Output " > Logging into Azure for $subscriptionId"
            az config set core.login_experience_v2=off

            # Attempt to log in
            az login --use-device-code --output none

            # Set the subscription after login
            Write-Output " > Setting subscription to $subscriptionId"
            az account set --subscription $subscriptionId

            # Verify subscription is correctly set
            $newContext = az account show --output json | ConvertFrom-Json
            if ($newContext.id -eq $subscriptionId) {
                Write-Output " > Successfully set the subscription to $subscriptionId"
            }
            else {
                Write-Output " > Failed to set the subscription to $subscriptionId. Please check your access rights."
            }
        }
    }

    $subscriptionId = az account show --query 'id' -o tsv
    $subscriptionFriendlyName = az account show --query 'name' -o tsv
    Write-Output "Checking quota for VM Family '$skuType' in '$location' for subscription: $subscriptionId - $subscriptionFriendlyName"
    Write-Warning "This can take 2 minutes to check and report back!!"

    # Get the list of VM SKUs for the given location
    $SKUFamily = az vm list-skus --location $location --query "[?resourceType=='virtualMachines'].{Name:name, Family:family}" | ConvertFrom-Json

    # Check if the SkuType is valid in the given location
    $familyInfo = $SKUFamily | Where-Object { $_.Name -eq $skuType }

    if ($familyInfo) {
        Write-Output "VM Family '$skuType' is available in the location '$location'. Checking quota..."

        # Get the quota information for the VM family
        $quotaInfo = az vm list-usage --location $location --query "[?name.value=='$($familyInfo.Family)']" | ConvertFrom-Json

        if ($quotaInfo) {
            foreach ($info in $quotaInfo) {
                Write-Warning "$($info.name.localizedValue): You have consumed $($info.currentValue)/$($info.limit) available quota"
            }
        }
        else {
            Write-Output "Quota information not available for VM Family '$skuType'"
        }
    }
    else {
        Write-Output "VM Family '$skuType' is not valid or not available in the location '$location'"
    }
}
