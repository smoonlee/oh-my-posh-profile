<#
.Name 
    New-PsProfile.ps1

.Author
    Simon Lee   
    @smoon_lee

#>

# Check Folder Path 
# PowerShell 7.0 : C:\Users\Default\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
# PowerShell 5.0 : C:\Users\Default\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
# VSCode         : C:\Users\Default\Documents\PowerShell\Microsoft.VSCode_profile.ps1

#Requires -RunAsAdministrator

param (
    [Parameter()]
    [switch] $ResetProfile
)

# Clear Screen
Clear-Host

# Script Functions
function Update-PowerShellModule {
    param (
        [string] $ModuleName
    )

    If ($PSVersionTable.PSVersion.Major -eq '5') {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    }

    try {
        $OnlineModule = (Find-Module -Repository 'PSGallery' -Name $Module -ErrorAction Stop).Version 
        $LocalModule = (Get-ChildItem -Path $env:ProgramFiles\WindowsPowerShell\Modules\$Module -ErrorAction SilentlyContinue).Name | Select-Object -Last 1
        If ($LocalModule -eq $OnlineModule) {
            Write-Output "PowerShell Module [$ModuleName] is up to date [Local: $($LocalModule), Online: $($OnlineModule)]"
        }
        If (!($LocalModule)) {
            Write-Output "Installing PowerShell Module [$ModuleName] version $($OnlineModule)"
            Save-Module -Repository 'PSGallery' -Name $ModuleName  -Path $env:ProgramFiles\WindowsPowerShell\Modules -Force -ErrorAction Stop
        }
        ElseIf ($LocalModule -ne $OnlineModule) {
            Write-Output "Updating PowerShell Module [$ModuleName] to version $($OnlineModule)"
            Save-Module -Repository 'PSGallery' -Name $ModuleName  -Path $env:ProgramFiles\WindowsPowerShell\Modules -Force -ErrorAction Stop
        }

    }
    catch {
        Write-Warning "Failed to update module [$ModuleName]. Error: $_"
    }
}

#
# Pre Flight Check, Core Modules Installation - Pwsh7, VSCode, Windows Terminal
#

Write-Output "-------------------------------------------------------"
Write-Output "        Oh My Posh Profile ::  Pre Flight Check        "
Write-Output "-------------------------------------------------------"

# Verbose OS Display
$OsCaptionName = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
Write-Output "OS Caption: $OsCaptionName" `r

# Windows 10: Windows Package Manager Installation Check
# https://learn.microsoft.com/en-us/windows/package-manager/winget/#install-winget
If ($OsCaptionName -match 'Microsoft Windows 10') {
    Write-Output "-> Checking for: Windows Package Manager - (winget)"
    if (!(Get-Command -Name "winget" -ErrorAction SilentlyContinue)) {
        Write-Warning "Winget Missing from System, Installing now!"

        $progressPreference = 'silentlyContinue'
        Write-Information "Downloading WinGet and its dependencies..."
        Invoke-WebRequest -Uri https://aka.ms/getwinget -OutFile "$Env:Temp\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile "$Env:TEmp\Microsoft.VCLibs.x64.14.00.Desktop.appx"
        Invoke-WebRequest -Uri https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.7.3/Microsoft.UI.Xaml.2.7.x64.appx -OutFile "$Env:Temp\Microsoft.UI.Xaml.2.7.x64.appx"
        Add-AppxPackage -Path "$Env:Temp\Microsoft.VCLibs.x64.14.00.Desktop.appx"
        Add-AppxPackage -Path "$Env:Temp\Microsoft.UI.Xaml.2.7.x64.appx"
        Add-AppxPackage -Path "$Env:Temp\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"

        Write-Output "winget Package Manager Installation, Complete!"
        Remove-Item -Path "$Env:Temp\Microsoft.VCLibs.x64.14.00.Desktop.appx"
        Remove-Item -Path "$Env:Temp\Microsoft.UI.Xaml.2.7.x64.appx"
        Remove-Item -Path "$Env:Temp\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    }

    if (Get-Command -Name "winget") {
        Write-Output "Found: winget.exe" `r
    }
}

# Prerequisite Application Check
Write-Output "-> Checking Prerequisite Applications"
$CoreApps = @(
    'Microsoft.PowerShell',
    'Microsoft.WindowsTerminal',
    'Microsoft.VisualStudioCode'
)

ForEach ($CoreApp in $CoreApps) {
    Write-Output "Checking for [$CoreApp]"

    $CoreAppCheck = winget.exe list --exact --query $CoreApp --accept-source-agreements
    If ($CoreAppCheck[-1] -notmatch $CoreApp) {
        If ($CoreApp -eq 'Microsoft.VisualStudioCode') {
            winget.exe install --silent --exact --query $CoreApp --Scope machine --accept-source-agreements
        }
        Else {
            winget.exe install --silent --exact --query $CoreApp --accept-source-agreements
        }
        
        Write-Output "" # Required for script spacing
    }
}

# PowerShell Application Paths
$Pwsh5App = "$Env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$Pwsh7App_1 = "$Env:ProgramFiles\PowerShell\7\pwsh.exe"
$Pwsh7App_2 = "$Env:LOCALAPPDATA\Microsoft\WindowsApps\Microsoft.PowerShell_8wekyb3d8bbwe\pwsh.exe"

# Test each path using Test-Path
if (Test-Path -Path $Pwsh7App_1) {
    $Pwsh7App = $Pwsh7App_1
    Write-Output `r "-> PowerShell Application Paths"
    Write-Output "PowerShell 7 Path: $Pwsh7App"
} 

if (Test-Path -Path $Pwsh7App_2) {
    $Pwsh7App = $Pwsh7App_2
    Write-Output `r "-> PowerShell Application Paths"
    Write-Output "PowerShell 7 Path: $Pwsh7App"
} 

If (Test-Path -Path $Pwsh5App) {
    Write-Output "PowerShell 5 Path: $Pwsh5App" `r
}

# PowerShell Modules Path 
$Pwsh7ConfigPath = "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell"
$Pwsh5ConfigPath = "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell"

# PowerShell Profile Paths 
$VsCodeProfilePath = "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.VSCode_profile.ps1"
$Pwsh7ProfilePath = "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.PowerShell_profile.ps1"
$Pwsh5ProfilePath = "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"

# Reset PowerShell Modules and PSProfile
if ($ResetProfile) {
    Write-Warning "Resetting Windows PowerShell Profile"

    # Remove Windows Terminal Settings.Json
    $SettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    If (Test-Path -Path $SettingsPath) {
        Remove-Item -Path $SettingsPath -Force
        Write-Output "[RESET] > Removing Windows Terminal Settings"
    }
    else {
        Write-Output "No Windows Terminal Settings Configured"
    }

    if (Test-Path -Path $Pwsh7ConfigPath) {
        Write-Output "[RESET] > Removing PowerShell 7 Modules and Profile"
        Remove-Item -Path $Pwsh7ConfigPath -Force -Recurse
    }
    else {
        Write-Output "No PowerShell 7 Profile Configured"
    }

    if (Test-Path -Path $Pwsh5ConfigPath) {
        Write-Output "[RESET] > Removing PowerShell 5 Modules and Profile"
        Remove-Item -Path $Pwsh5ConfigPath -Force -Recurse
    }
    else {
        Write-Output "No PowerShell 5 Profile Configured" `r
    }
}

# Verbose Message
Write-Output "-------------------------------------------------------"
Write-Output "        Oh My Posh Profile ::  Pwsh Module Install     "
Write-Output "-------------------------------------------------------"

# Configure PowerShell Execution Policy 
Write-Output `r "-> Configure PowerShell Execution Policy [RemoteSigned]"
& "$Pwsh7App" -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"
& "$Pwsh5App" -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"
Write-Output "Execution Policy Set: [RemoteSigned] :: Scope: [Current User]"

# Update Local PowerShell Modules
Write-Output `r "-> Checking PowerShell 5 Modules"
$Pwsh5Modules = @(
    'PackageManagement',
    'PowerShellGet',
    'PSReadLine',
    'Pester'
)

ForEach ($Module in $Pwsh5Modules) {
    Update-PowerShellModule -ModuleName $Module
}

# Update Local PowerShell Modules
Write-Output `r "-> Checking PowerShell 7 Modules"
$Pwsh7Modules = @(
    'Posh-Git',
    'Terminal-Icons'
    'Az'
)

ForEach ($Module in $Pwsh7Modules) {
    Update-PowerShellModule -ModuleName $Module
}

# Verbose Message
Write-Output "" # Required for verbose script formatting
Write-Output "-------------------------------------------------------"
Write-Output "        Oh My Posh Profile ::  Winget Module Install   "
Write-Output "-------------------------------------------------------"

# Configure WinGet 
Write-Output `r "-> Checking Winget Modules"
$WinGetModules = @(
    'JanDeDobbeleer.OhMyPosh',
    'Git.Git',
    'GitHub.cli',
    'Microsoft.AzureCLI',
    'Microsoft.Azure.Kubelogin',
    'Kubernetes.kubectl',
    'Helm.Helm'
)

ForEach ($Module in $WinGetModules) {
    Write-Output "Checking for [$Module]"

    $ModuleCheck = winget.exe list --exact --query $Module --accept-source-agreements
    If ($ModuleCheck[-1] -notmatch $Module) {
        winget.exe install --silent --exact --query $Module --accept-source-agreements
        Write-Output "" # Required for script spacing
    }
}

# Verbose Message
Write-Output "" # Required for verbose script formatting
Write-Output "-------------------------------------------------------"
Write-Output "        Oh My Posh Profile ::  Nerd Font Install       "
Write-Output "-------------------------------------------------------"

$NerdFontPackageName = 'CascadiaCode.zip'
$NerdFontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/$NerdFontPackageName"
$NerdFontName = 'CaskaydiaCoveNerdFont-Regular.ttf'
$FilePath = "$Env:Temp\$($NerdFontPackageName.TrimEnd('.zip'))\$NerdFontName"
$FontName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
$DestinationPath = "C:\Windows\Fonts\$FontName.ttf"

if (!(Test-Path -Path $DestinationPath)) {
    Write-Output "-> Starting Installation of Nerd Font [ $($NerdFontPackageName.Trim('.zip')) ]"

    try {
        Write-Output "Downloading Nerd Font: $($NerdFontPackageName.TrimEnd('.zip'))"
        Invoke-WebRequest -Uri $NerdFontUrl -OutFile "$Env:Temp\$NerdFontPackageName"

        Write-Output "Extracting: $($NerdFontPackageName.TrimEnd('.zip'))"
        Expand-Archive -Path "$Env:Temp\$NerdFontPackageName" -DestinationPath "$Env:Temp\$($NerdFontPackageName.TrimEnd('.zip'))" -Force
        Copy-Item -Path $FilePath -Destination $DestinationPath -Force

        $FontRegistryPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
        $FontEntry = "$FontName (TrueType)" # Modify this if the font is not TrueType
        New-ItemProperty -Path $FontRegistryPath -Name $FontEntry -PropertyType String -Value $DestinationPath -Force | Out-Null

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

        Write-Output "Nerd Font [$NerdFontName] Installed"
    }
    catch {
        Write-Warning "Failed to install Nerd Font. Error: $_"
    }
}
else {
    Write-Output "Nerd Font [$NerdFontName] is already installed" `r
}

# Verbose Message
Write-Output "-------------------------------------------------------"
Write-Output "        Oh My Posh Profile ::  WinTerm Configuration   "
Write-Output "-------------------------------------------------------"

# Create Local Code Folder
$RootCodeFolder = "C:\code"
If (!(Test-Path -Path $RootCodeFolder)) {
    New-Item -ItemType 'Directory' -Path $RootCodeFolder | Out-Null
    Write-Output "Created Code Folder : $RootCodeFolder"
}

# Windows Terminal Config 
$settingsDefault = "https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile/main/windows-terminal-default-settings.json"
$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"  
$desiredOrder = @("PowerShell", "Windows PowerShell", "Azure Cloud Shell", "Command Prompt")  

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
            "elevate": true,
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

# 
Write-Output `r "Configuring PowerShell Oh-My-Posh Theme"

Write-Output "Downloading Oh-My-Posh Profile: [quick-term-smoon] Json"
$PoshProfileGistUrl = "https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile/main/quick-term-smoon.omp.json"
$PoshProfileName = Split-Path -Path $PoshProfileGistUrl -Leaf
Invoke-WebRequest -Uri $PoshProfileGistUrl -OutFile "$Env:LOCALAPPDATA\Programs\oh-my-posh\themes\$PoshProfileName"

# PowerShell_Profile
$PSProfileConfig = @'
# Import PowerShell Modules
Import-Module -Name 'Posh-Git'
Import-Module -Name 'Terminal-Icons'
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
Write-Output "  Windows PowerShell Profile Configuration Complete!   "
Write-Output "-------------------------------------------------------"

# Finally, Launch Oh-My-Posh
. $PROFILE
