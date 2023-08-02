
# Check Folder Path 
# PowerShell 7.0 : C:\Users\MSFTAdmin\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
# PowerShell 5.0 : C:\Users\MSFTAdmin\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
# VSCode         : C:\Users\MSFTAdmin\Documents\PowerShell\Microsoft.VSCode_profile.ps1

#Requires -RunAsAdministrator

param (
    [Parameter()]
    [switch] $ResetProfile
)

# PowerShell Application Paths
$Pwsh7App = "$env:LOCALAPPDATA\Microsoft\WindowsApps\Microsoft.PowerShell_8wekyb3d8bbwe\pwsh.exe"
$Pwsh5App = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

# PowerShell Modules Path 
$Pwsh7ConfigPath = "$([Environment]::GetFolderPath("MyDocuments"))\PowerShell"
$Pwsh5ConfigPath = "$([Environment]::GetFolderPath("MyDocuments"))\WindowsPowerShell"

# PowerShell Profile Paths 
$VsCodeProfilePath = "$([Environment]::GetFolderPath("MyDocuments"))\PowerShell\Microsoft.VSCode_profile.ps1"
$Pwsh7ProfilePath = "$([Environment]::GetFolderPath("MyDocuments"))\PowerShell\Microsoft.PowerShell_profile.ps1"
$Pwsh5ProfilePath = "$([Environment]::GetFolderPath("MyDocuments"))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"


# Clear Screen
Clear-Host

# PowerShell Profile Setup Verbose Message
Write-Output "-------------------------------------------------------"
Write-Output "    Windows PowerShell Profile Configuration Script    "
Write-Output "-------------------------------------------------------"


# Reset PowerShell Modules and PSProfile
if ($ResetProfile) {
    Write-Warning "Resetting Windows PowerShell Profile"
 
    if (Test-Path -Path $Pwsh7ConfigPath) {
        Write-Output "Removing PowerShell 7 Modules and Profile"
        Remove-Item -Path $Pwsh7ConfigPath -Force -Recurse
    }
    Else {
        Write-Output "No PowerShell 7 Profile Configured"
    }
 
    if (Test-Path -Path $Pwsh5ConfigPath) {
        Write-Output "Removing PowerShell 5 Modules and Profile" `r
        Remove-Item -Path $Pwsh5ConfigPath -Force -Recurse
    }
    Else {
        Write-Output "No PowerShell 5 Profile Configured" `r
    }
}

# Configure PowerShell Execution Policy 
Write-Output "Configure PowerShell Execution Policy [RemoteSigned]"
& "$Pwsh7App" -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"
& "$Pwsh5App" -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"

# Configure PowerShell Modules and Profile Folder
If (!(Test-Path -Path $Pwsh5ProfilePath)) {
    New-Item -ItemType 'Directory' -Path $Pwsh5ConfigPath  | Out-Null
}


# Update Local PowerShell Modules
Write-Output `r "> Checking PowerShell 5 Modules"
$Pwsh5Modules = @(
    'PackageManagement',
    'PowerShellGet',
    'PSReadLine',
    'Pester'
)

ForEach ($Module in $Pwsh5Modules) {
    $OnlineModuleVersion = (Find-Module -Repository 'PSGallery' -Name $Module).Version 
    $LocalModuleVersion = (Get-ChildItem -Path $env:ProgramFiles\WindowsPowerShell\Modules\$Module -ErrorAction SilentlyContinue).Name | Select -Last 1
    Write-Output "Checking PowerShell Module [ $Module ] Online: $OnlineModuleVersion, Local: $LocalModuleVersion"
    if ((Get-ChildItem -Path $env:ProgramFiles\WindowsPowerShell\Modules\$Module -ErrorAction SilentlyContinue).Name -notcontains $OnlineModuleVersion.ToString()) {
        Write-Output "Downloading $Module version: $ModuleVersion to $env:ProgramFiles\WindowsPowerShell\Modules\$Module"
        Save-Module -Repository 'PSGallery' -Name $Module -Path $env:ProgramFiles\WindowsPowerShell\Modules -Force
    }
}

# Update Local PowerShell Modules
Write-Output `r "> Checking PowerShell 7 Modules"
$Pwsh7Modules = @(
    'Posh-Git',
    'Az'
)

ForEach ($Module in $Pwsh7Modules) {
    $OnlineModuleVersion = (Find-Module -Repository 'PSGallery' -Name $Module).Version 
    $LocalModuleVersion = (Get-ChildItem -Path $env:ProgramFiles\WindowsPowerShell\Modules\$Module -ErrorAction SilentlyContinue).Name | Select -Last 1
    Write-Output "Checking PowerShell Module [ $Module ] Online: $OnlineModuleVersion, Local: $LocalModuleVersion"
    if ((Get-ChildItem -Path $env:ProgramFiles\WindowsPowerShell\Modules\$Module -ErrorAction SilentlyContinue).Name -notcontains $OnlineModuleVersion.ToString()) {
        Write-Output "Downloading $Module version: $ModuleVersion to $env:ProgramFiles\WindowsPowerShell\Modules\$Module"
        Save-Module -Repository 'PSGallery' -Name $Module -Path $env:ProgramFiles\WindowsPowerShell\Modules -Force
    }
}

# Configure WinGet 
Write-Output `r "> Checking Winget Modules"
$WinGetModules = @(
    'JanDeDobbeleer.OhMyPosh',
    'Git.Git',
    'GitHub.cli',
    'Microsoft.AzureCLI',
    'Microsoft.Azure.Kubelogin'
    'Kubernetes.kubectl',
    'Helm.Helm'
)

# Check Module 
ForEach ($Module in $WinGetModules) {
    Write-Output "Checking for [$Module]"

    $ModuleCheck = winget.exe list --exact --query $Module --accept-source-agreements
    If ($ModuleCheck[-1] -notmatch $Module) {
        winget.exe install --silent --exact --query $Module --accept-source-agreements
    }
}


# Download Nerd Font and Install
# Nerd Font Installation Variables
$NerdFontPackageName = 'CascadiaCode.zip'
$NerdFontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/$NerdFontPackageName"
$NerdFontName = 'CaskaydiaCoveNerdFont-Regular.ttf'
$FilePath = "$Env:Temp\$($NerdFontPackageName.TrimEnd('.zip'))\$NerdFontName"
$FontName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
$DestinationPath = "C:\Windows\Fonts\$FontName.ttf"

If (!(Test-Path -Path $DestinationPath)) {

    # Verbose
    Write-Output `r "> Starting Installation of Nerd Font [ $($NerdFontPackageName.Trim('.zip')) ]"

    Write-Output "Downloading Nerd Font: $($NerdFontPackageName.TrimEnd('.zip'))"
    Invoke-WebRequest -Uri $NerdFontUrl -OutFile "$Env:Temp\$NerdFontPackageName"

    # Extract Nerd Font
    Write-Output "Extracting: $($NerdFontPackageName.TrimEnd('.zip'))"
    Expand-Archive -Path "$Env:Temp\$NerdFontPackageName" -DestinationPath "$Env:Temp\$($NerdFontPackageName.TrimEnd('.zip'))" -Force

    # Copy the font file to the Windows Fonts directory
    Copy-Item -Path $FilePath -Destination $DestinationPath -Force

    # Register the font in the Windows registry
    $FontRegistryPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    $FontEntry = "$FontName (TrueType)" # Modify this if the font is not TrueType
    New-ItemProperty -Path $FontRegistryPath -Name $FontEntry -PropertyType String -Value $DestinationPath -Force | Out-Null

    # Send a message to update the font cache
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
}

# Verify Nerd Font Installed
if (Test-Path -Path $DestinationPath) {
    Write-Output `r "$NerdFontName : Installed" `r
}

# Create Local Code Folder
$RootCodeFolder = "C:\Code"
If (!(Test-Path -Path $RootCodeFolder)) {
    New-Item -ItemType 'Directory' -Path $RootCodeFolder | Out-Null
    Write-Output "Created Code Folder : $RootCodeFolder"
}


# Windows Terminal Config 
$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"  # Update this with the actual path to your settings.json file
$desiredOrder = @("PowerShell", "Windows PowerShell", "Azure Cloud Shell", "Command Prompt" )  # Update this array with the desired order of profile names

try {
    # Load the content of the settings.json file
    $settingsContent = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json

    # Get the list of existing profiles
    $profiles = $settingsContent.profiles.list

    # Create a hashtable to map profile name to profile data
    $profileData = @{}
    foreach ($profile in $profiles) {
        $profileData[$profile.name] = $profile
    }

    # Create a list to hold the reordered profiles
    $reorderedProfiles = @()

    # Reorder the profiles based on the desired order
    foreach ($profileName in $desiredOrder) {
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

    # Convert back to JSON format
    $updatedSettings = $settingsContent | ConvertTo-Json -Depth 100

    # Save the updated settings to the file
    Set-Content -Path $settingsPath -Value $updatedSettings -Force

    # Apply default settings to the terminal profiles
    $TerminalProfileContent = Get-Content $settingsPath
    $TerminalProfileContent = $TerminalProfileContent -replace '("defaults": {})', @"
        "defaults": 
        {
            "colorScheme": "One Half Dark",
            "elevate": true,
            "font": 
            {
                "face": "CaskaydiaCove Nerd Font",
                "size": 10.0
            },
            "startingDirectory": "C:\\Code"
        }
"@
    $TerminalProfileContent | Set-Content $settingsPath

    Write-Output "Windows Terminal Configuration Updated"
}
catch {
    Write-Host "An error occurred: $_"
}

# 
Write-Output `r "Configuring PowerShell Oh-My-Posh Theme"

Write-Output "Downloading Oh-My-Posh Profile: [quick-term-smoon] Json"
$PoshProfileGistUrl = "https://gist.githubusercontent.com/smoonlee/437a1a69a658a704928db5e8bd13a5b5/raw/e6e4e743bb0f743da18baf732e3bce4dc33757b9/quick-term-smoon.omp.json"
$PoshProfileName = Split-Path -Path $PoshProfileGistUrl -Leaf
Invoke-WebRequest -Uri $PoshProfileGistUrl -OutFile "$env:POSH_THEMES_PATH\$PoshProfileName"

# PowerShell_Profile
$PSProfileConfig = @'
# Import PowerShell Modules
Import-Module -Name 'Posh-Git'
Import-Module -Name 'PSReadLine' -MinimumVersion '2.1.0'

# PSReadLine Config
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -HistoryNoDuplicates:$True
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

(@(& "$Env:LOCALAPPDATA\Programs\oh-my-posh\bin\oh-my-posh.exe" init pwsh --config="$Env:LOCALAPPDATA\Programs\oh-my-posh\themes\{0}" --print) -join "`n") | Invoke-Expression

# Oh-My-Posh Configuration
$env:POSH_AZURE_ENABLED = $true
$env:POSH_GIT_ENABLED = $true
'@

# Create Default Profile (PowerShell 7)
$PSProfileConfig = $PSProfileConfig -f $PoshProfileName
$PSProfileConfig | Set-Content -Path $Pwsh7ProfilePath -Force

# Create PowerShell Profile Symbolic Links
New-Item -ItemType 'SymbolicLink' -Path $Pwsh5ProfilePath -Target $Pwsh7ProfilePath -Force | Out-Null
Write-Output "Created SymbolicLink for Windows PowerShell 5 Profile"

New-Item -ItemType 'SymbolicLink' -Path $VsCodeProfilePath -Target $Pwsh7ProfilePath -Force | Out-Null
Write-Output "Created SymbolicLink for VS Code Profile"

# Setup Complete
Write-Output `r "-------------------------------------------------------"
Write-Output "  Windows PowerShell Profile Configuration Complete!  "
Write-Output "-------------------------------------------------------"

# Finally, Launch Oh-My-Posh
. $PROFILE