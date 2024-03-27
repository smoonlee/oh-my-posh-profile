
#Requires -RunAsAdministrator

# Script Parameter Block
param (
    [Parameter(Position = 0, Mandatory = $true)] [validateSet("User", "Machine")] [string]$installScope = 'User',
    [switch] $resetProfile
)

# Pre Flightation PowerShell
# PowerShell 5 Path: "$Env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
# PowerShell 7 (User) Path: "$Env:LocalAppData\Local\Microsoft\WindowsApps\Microsoft.PowerShell_8wekyb3d8bbwe\pwsh.exe"
# PowerShell 7 (Machine) Path: "$Env:ProgramFiles\PowerShell\7\pwsh.exe"

# PowerShell Profile Paths 
$VsCodeProfilePath = "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.VSCode_profile.ps1"
$Pwsh7ProfilePath = "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.PowerShell_profile.ps1"
$Pwsh5ProfilePath = "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"

function Reset-PSProfile {
    # Stage Heading
    Write-Output `r "[ PS Profile Reset ] : Resetting Windows Terminal and PS Profile!"

    if (Test-Path -Path "$Env:UserProfile\Documents\Powershell" ) {
        Write-Output "[ PS Profile Reset ] : Resetting 'PowerShell' Directory"
        Remove-Item -Path "$Env:UserProfile\Documents\Powershell" -Recurse -Force 
    }
    
    if (Test-Path -Path "$Env:UserProfile\Documents\WindowsPowershell" ) {
        Write-Output "[ PS Profile Reset ] : Resetting 'WindowsPowerShell' Directory"
        Remove-Item -Path "$Env:UserProfile\Documents\WindowsPowershell" -Recurse -Force
    }
    
    if (Test-Path -Path "$Env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe" ) {
        Write-Output "[ PS Profile Reset ] : Resetting Windows Terminal Json"
        Remove-Item -Path "$Env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" -Force
    }
    
    Write-Output "[ PS Profile Reset ] : Reset Complete!"
}

function Install-PreFlightApps {
    param (
        [string] $installScope
    )

    $preFlightApps = @(
        'Microsoft.PowerShell',
        'Microsoft.WindowsTerminal',
        'Microsoft.VisualStudioCode'  
    )

    # Stage Heading
    Write-Output `r "[ PS Profile Setup ] : Core Application Installation"

    Write-Output '[ Pre Flight Check ] : Checking for WinGet-CLI'
    # WinGet CLI GitHub: https://github.com/microsoft/winget-cli
    $wingetReleaseUrl = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
    $wingetLatestRelease = (Invoke-WebRequest -Uri $wingetReleaseUrl).Content | ConvertFrom-Json
    $wingetLatestReleaseTag = $wingetLatestRelease.tag_name
    if (winget.exe) {
        $wingetLocalVersion = winget --version
        Write-Output "[ Pre Flight Check ] : Checking for WinGet-CLI [detected version: $wingetLocalVersion]"
        if ($wingetLocalVersion -notmatch $wingetLatestReleaseTag) {
            Write-Warning "[ Pre Flight Check ] : Newer Version Available [$wingetLatestReleaseTag]"
            Write-Warning "[ Pre Flight Check ] : Downloading msixbundle for [$wingetLatestReleaseTag]"
            $wingetLatestReleaseUrl = ($wingetLatestRelease.assets.browser_download_url | Where-Object { $_ -like "*.msixbundle" })
        
            # This is faster than Invoke-WebRequest
            # https://stackoverflow.com/questions/28682642/powershell-why-is-using-invoke-webrequest-much-slower-than-a-browser-download 
            $wingetWebClient = New-Object net.webclient 
            $wingetWebClient.DownloadFile($wingetLatestReleaseUrl, "$Env:TEMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle")
        
            # Install Package
            Add-AppxPackage -Path "$Env:Temp\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -Verbose

            # Update WinGet CLI Cache
            winget source update

            # Remove Install file
            Remove-Item -Path "$Env:TEMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -Force | Out-Null

            Write-Output "[ Pre Flight Check ] : WinGet-CLI Installation Complete"
        }
    }

    forEach ($preFlightApp in $preFlightApps) {
        Write-Output "[ Pre Flight Check ] : Checking for [$preFlightApp]"
        $appCheck = winget list --accept-source-agreements --exact $preFlightApp
        if (($appCheck[-1]) -notmatch $preFlightApp) {
            Write-Warning "[ Pre Flight Check ] : [$preFlightApp] missing from your device" 
            Write-Output "[ Pre Flight Check ] : [$preFlightApp] Installing"

            winget.exe install --accept-source-agreements --accept-package-agreements --scope Machine --silent --exact --Id $preFlightApp --force  
        }

        if ($appCheck) {
            Write-Output "[ Pre Flight Check ] : [$preFlightApp] detected, Checking for Updates..."
            winget.exe upgrade --accept-source-agreements --accept-package-agreements --silent --exact --Id $preFlightApp --force  
        }
    }
}

function Install-TerminalApps {
    $terminalApps = @(
        'JanDeDobbeleer.OhMyPosh',
        'Git.Git',
        'GitHub.cli',
        'Microsoft.AzureCLI',
        'Microsoft.Azure.Kubelogin',
        'Kubernetes.kubectl',
        'Helm.Helm'   
    )

    forEach ($terminalApp in $TerminalApps) {
        Write-Output "[ Pre Flight Check ] : Checking for [$terminalApp]"
        $appCheck = winget list --exact $terminalApp
        if (($appCheck[-1]) -notmatch $terminalApp) {
            Write-Warning "[ Pre Flight Check ] : [$terminalApp] missing from your device" 
            Write-Output "[ Pre Flight Check ] : [$terminalApp], Scope [System Wide Application]"
            winget.exe install --accept-source-agreements --silent --exact --Id $terminalApp
        }        
    }
}

function Install-PwshModules {
    param (
        [string] $installScope
    )
    
    $pwshCoreModules = @(
        'PackageManagement',
        'PowerShellGet' 
    )

    $pwshModules = @(
        #'Az',
        'Posh-Git',
        'PSReadLine',
        'Pester',
        'Terminal-Icons'
    )

    if ($installScope -eq 'User') {
        $installScope = 'CurrentUser'
    }
    
    if ($installScope -eq 'Machine') {
        $installScope = 'AllUsers'
    }

    # Stage Heading
    Write-Output `r "[ PS Profile Setup ] : PowerShell Module Installation"

    # Check PackageProvider NuGet
    if ($PSVersionTable.PSVersion.Major -eq '5') {
        Write-Output "[  Module Install  ] : [Pwsh 5] : Updating NuGet Package"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    }

    # Check PowerShell Gallery Installation Policy
    $installPolicy = 'Trusted'
    $psRepository = Get-PSRepository -Name 'PSGallery'
    If ($psRepository.InstallationPolicy -ne $installPolicy) {
        Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' 
        Write-Output "[  Module Install  ] : PSGallery Configured 'Trusted'"
    }

    forEach ($pwshCoreModule in $pwshCoreModules) {
        Write-Output "[  Module Install  ] : Installing [$pwshCoreModule]"
        Install-Module -Repository 'PSGallery' -Scope AllUsers -Name $pwshCoreModule -SkipPublisherCheck -Force
    }

    forEach ($pwshModule in $pwshModules) {
        Write-Output "[  Module Install  ] : Checking for [$pwshModule]"
        $localModule = (Get-Module -ListAvailable -Name $pwshModule -ErrorAction SilentlyContinue).version | Select-Object -Last 1
        $onlineModule = (Find-Module -Repository PSGallery -Name $pwshModule ).version

        if (([string]::IsNullOrEmpty($localModule))) {
            Write-Output "[  Module Install  ] : Installing [$pwshModule] version [$onlineModule]"
            Install-Module -Repository 'PSGallery' -Scope $installScope -Name $pwshModule -SkipPublisherCheck -Force
        } elseif ($localModule -ne $onlineModule) {
            Write-Output "[  Module Install  ] : Updating [$pwshModule] to version [$onlineModule]"
            Install-Module -Repository 'PSGallery' -Scope $installScope -Name $pwshModule -SkipPublisherCheck -Force
        }
    }

    if ($PSVersionTable.PSVersion.Major -eq '7') {
        Write-Output "[  Module Install  ] : Patching PSReadLine for Pwsh 5"
        Save-Module -Name 'PSReadLine' -Path "C:\Program Files\WindowsPowerShell\Modules\" -Force
    }  
}

function Install-NerdFontPackage {
    # Font Downloads - https://www.nerdfonts.com/font-downloads
    # Github - https://github.com/ryanoasis/nerd-fonts/releases/latest
    $nerdFontPackageName = 'CascadiaCode.zip'
    $nerdFontFileName = 'CaskaydiaCoveNerdFont-Regular.ttf'
    $nerdFontName = $nerdFontFileName.Trim('.ttf')
    $nerdFontLatestUrl = 'https://github.com/ryanoasis/nerd-fonts/releases/latest'
    $nerdFontResponse = Invoke-WebRequest -Uri $nerdFontLatestUrl
    $nerdFontDownloadUrl = ($nerdFontResponse.links | Where-Object href -like *$nerdFontPackageName).href
    $windowsFontPath = 'C:\Windows\Fonts'
    
    # Stage Heading
    Write-Output `r "[ PS Profile Setup ] : Nerd Font Installation"
    If (Test-Path -Path $windowsFontPath\$nerdFontFileName) {
        Write-Output "[  Font   Install  ] : Nerd Font '$nerdFontFileName' already installed"
        return
    }
    
    # Download Nerd Font
    Write-Output "[  Font   Install  ] : Downloading Nerd Font [$nerdFontPackageName]"
    Invoke-WebRequest -Uri $nerdFontDownloadUrl -OutFile $Env:TEMP\$nerdFontPackageName
    
    # Extract Zip File
    Write-Output "[  Font   Install  ] : Extracting [$nerdFontPackageName] - [$Env:Temp\$($nerdFontPackageName.Trim('.zip'))]"
    Expand-Archive -Path $Env:TEMP\$nerdFontPackageName -DestinationPath "$Env:Temp\$($nerdFontPackageName.Trim('.zip'))"
    Copy-Item -Path "$Env:Temp\$($nerdFontPackageName.Trim('.zip'))\$($nerdFontFileName)" -Destination "$windowsFontPath\$nerdFontFileName" -Force

    # Install Font
    $FontRegistryPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    $FontEntry = "$nerdFontName (TrueType)" # Modify this if the font is not TrueType
    New-ItemProperty -Path $FontRegistryPath -Name $FontEntry -PropertyType String -Value "$windowsFontPath\$nerdFontFileName"-Force | Out-Null

    $wshShell = New-Object -ComObject WScript.Shell
    $FontCachePath = "$env:SystemRoot\System32\FNTCACHE.DAT"
    $wshShell.AppActivate('Font Viewer') | Out-Null
    Start-Sleep -Milliseconds 500
    $wshShell.SendKeys('{F5}')
    Start-Sleep -Milliseconds 500
    $wshShell.SendKeys('{TAB}{ENTER}')
    Start-Sleep -Milliseconds 500
    if (Test-Path $FontCachePath) {
        Remove-Item $FontCachePath -Force
    }

    # Remove Install Files
    Remove-Item -Path "$Env:Temp\$($nerdFontPackageName.Trim('.zip'))" -Recurse -Force | Out-Null
    Write-Output "[  Font   Install  ] : Removed: $Env:Temp\$($nerdFontPackageName.Trim('.zip'))"
    
    Remove-Item -Path $Env:TEMP\$nerdFontPackageName -Force | Out-Null
    Write-Output "[  Font   Install  ] : Removed: $Env:TEMP\$nerdFontPackageName"
    
    # Complete
    Write-Output "[  Font   Install  ] : Nerd Font '$nerdFontFileName' Installed"
}

function Set-WindowsTerminalConfig {
    
    $localCodePath = 'C:\Code'
    $settingsDefault = "https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile/main/windows-terminal-default-settings.json"
    $settingsPath = "$Env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"  
    $desiredOrder = @("PowerShell", "Windows PowerShell", "Azure Cloud Shell", "Command Prompt")  

    # Stage Heading
    Write-Output `r "[ PS Profile Setup ] : Windows Terminal Configuration"

    if (!(Test-Path $localCodePath)) {
        Write-Output "[  Profile Config  ] : Creating Local Code Folder"
        New-Item -ItemType 'Directory' -Path $localCodePath | Out-Null
        Write-Output "[  Profile Config  ] : Local Code Folder Created $localCodePath"
    }
    
    #
    Write-Output "[  Profile Config  ] : Configure Windows Terminal Settings"
    
    If (!(Test-Path -Path $settingsPath)) {
        Invoke-WebRequest -Uri $settingsDefault -OutFile $settingsPath
    }

    try {
        # Import Windows Terminal Settings.json file
        $settingsContent = Get-Content -Path $settingsPath
    
        # Apply Windows Terminal Defaults 
        $terminalConfigDefaults = @"
        "defaults": {
            "colorScheme": "One Half Dark",
            "cursorShape": "underscore",
            "elevate": false,
            "font": {
                "face": "CaskaydiaCove Nerd Font",
                "size": 10.0
            },
            "startingDirectory": "C:\\code"
        }
"@
        $updatedConfig = $settingsContent -replace '("defaults": {})', $terminalConfigDefaults
        $updatedConfig | Set-content $settingsPath

        # Import Winodws Terminal Settings.json file
        $settingsContent = Get-Content -Path $settingsPath | ConvertFrom-Json
        $defaultProfileList = $settingsContent.profiles.list

        # Create Hash Table for current Console profiles
        $profileData = @{}
        ForEach ($shellProfile in $defaultProfileList) {
            $profileData[$shellProfile.name] = $shellProfile
        }

        # Update Priority of Console profiles
        $reorderedProfiles = @()

        # Reorder the profiles based on the desired order
        ForEach ($profileName in $desiredOrder) {
            if ($profileData.ContainsKey($profileName)) {
                $reorderedProfiles += $profileData[$profileName]
                $profileData.Remove($profileName)
            }
        }

        # Append any remaining profiles (not found in the desired order)
        foreach ($remainingProfile in $profileData.Values) {
            $reorderedProfiles += $remainingProfile
        }

        # Update the profiles list in the settings
        $settingsContent.profiles.list = $reorderedProfiles
        $updatedConfig = $settingsContent | ConvertTo-Json -Depth 100
        $updatedConfig | Set-content $settingsPath

    }
    catch {
        Write-Host "An error occurred: $_"
    }    

    Write-Output "[  Profile Config  ] : Configure PowerShell Profile"
    Write-Output "[  Profile Config  ] : Downloading Posh Profile 'quick-term-smoon.omp.json'"
    $PoshProfileGistUrl = "https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile/main/quick-term-smoon.omp.json"
    $PoshProfileName = Split-Path -Path $PoshProfileGistUrl -Leaf
    Invoke-WebRequest -Uri $PoshProfileGistUrl -OutFile "$Env:LOCALAPPDATA\Programs\oh-my-posh\themes\$PoshProfileName"

    # PowerShell_Profile
    $PSProfileConfig = @'
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
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# Oh My Posh Configuration
$env:POSH_AZURE_ENABLED = $true
$env:POSH_GIT_ENABLED = $true

# Load Oh My Posh Theme
(@(& "$Env:LOCALAPPDATA\Programs\oh-my-posh\bin\oh-my-posh.exe" init pwsh --config="$Env:LOCALAPPDATA\Programs\oh-my-posh\themes\{0}" --print) -join "`n") | Invoke-Expression


'@

    if ($PSVersionTable.PSVersion.Major -eq '5') {
        $PSProfileConfig = $PSProfileConfig -f $PoshProfileName

        if (!($Pwsh5ProfilePath)) {
            New-Item -ItemType 'Directory' -Path $Pwsh5ProfilePath -Force | Out-Null
        }

        $PSProfileConfig | Set-Content -Path $Pwsh5ProfilePath | Out-Null
        New-Item -ItemType 'SymbolicLink' -Target $Pwsh5ProfilePath -Path $Pwsh7ProfilePath -Force | Out-Null
        New-Item -ItemType 'SymbolicLink' -Target $Pwsh5ProfilePath -Path $VsCodeProfilePath -Force | Out-Null
    }

    if ($PSVersionTable.PSVersion.Major -eq '7') {
        $PSProfileConfig = $PSProfileConfig -f $PoshProfileName

        if (!($Pwsh7ProfilePath)) {
            New-Item -ItemType 'Directory' -Path $Pwsh7ProfilePath | Out-Null
        }

        $PSProfileConfig | Set-Content -Path $Pwsh7ProfilePath | Out-Null
        New-Item -ItemType 'SymbolicLink' -Target $Pwsh7ProfilePath -Path $Pwsh5ProfilePath -Force | Out-Null
        New-Item -ItemType 'SymbolicLink' -Target $Pwsh7ProfilePath -Path $VsCodeProfilePath -Force | Out-Null
    }

}

function Set-VSCodeFontFamily {
    # # Stage Heading
    # Write-Output `r "[ PS Profile Setup ] : Visual Studio Code Configuration"

    # # VSCode Settings Path
    # $vsCodeSettingsPath = "$([Environment]::GetFolderPath('MyDocuments'))\Code\User\settings.json"

    # # VSCode Font Family
    # $vsCodeFontFamily = "Consolas, 'Courier New', 'CaskaydiaCove Nerd Font'"
    

    
}

function Set-CrossPlatformModuleSupport {
    # Stage Heading
    Write-Output `r "[ PS Profile Setup ] : PowerShell Module Cross Version Support"

    if ($PSVersionTable.PSVersion.Major -eq '5') {
        if (Test-Path -Path $Env:UserProfile\Documents\PowerShell\Modules) {
            Remove-Item -Path "$Env:UserProfile\Documents\PowerShell\Modules" -Recurse -Force
        }
        
        # Target - Source Folder # Path - Link Folder
        New-Item -ItemType 'SymbolicLink' -Target 'C:\Users\Simon\Documents\WindowsPowerShell\Modules' -Path 'C:\Users\Simon\Documents\PowerShell\Modules' -Force | Out-Null
        Write-Output "[  Cross Platform  ] : Symbolic Link Created from 'WindowsPowerShell' to 'PowerShell' Modules"
    }

    if ($PSVersionTable.PSVersion.Major -eq '7') {
        if (Test-Path -Path "$Env:UserProfile\Documents\WindowsPowerShell\Modules" ) {
            Remove-Item -Path "$Env:UserProfile\Documents\WindowsPowerShell\Modules" -Recurse -Force
        }

        # Target - Source Folder # Path - Link Folder
        New-Item -ItemType 'SymbolicLink' -Target 'C:\Users\Simon\Documents\PowerShell\Modules' -Path 'C:\Users\Simon\Documents\WindowsPowerShell\Modules' -Force | Out-Null
        Write-Output "[  Cross Platform  ] : Symbolic Link Created from 'PowerShell' to 'WindowsPowerShell' Modules"
    }
}

#
Write-Output '--------------------------------------'
Write-Output '  PS Profile : Windows Installer 2.0  '
Write-Output '--------------------------------------'

# Verbose OS Display
$OsCaptionName = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
Write-Output "OS Caption: $OsCaptionName" 
Write-Output "> Install Scope: $installScope"

if ($resetProfile) {
    #
    Reset-PSProfile
}

#
Install-PreFlightApps

#
Install-TerminalApps

#
Install-PwshModules -installScope $installScope

#
Install-NerdFontPackage

#
Set-WindowsTerminalConfig

#
Set-VSCodeFontFamily

#
Set-CrossPlatformModuleSupport 

# Finally, Launch Oh-My-Posh
. $PROFILE