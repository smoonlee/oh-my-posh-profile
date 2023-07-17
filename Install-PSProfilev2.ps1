
#Requires -RunAsAdministrator

Write-Output "#################################"
Write-Output "     New Device Setup Script     "
Write-Output "#################################"

# Configure PowerShell Execution Policy 
# PowerShell 7
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass

# PowerShell 5
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass

# Configure PSGallery 
$PSGalleryInstallationPolicy = (Get-PSRepository -Name 'PSGallery').InstallationPolicy 
If ($PSGalleryInstallationPolicy -eq 'Untrusted') {
    Write-Warning "New System Configuration, Currently PSGallery InstallationPolicy is: Untrusted"
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted'
}

# 
If ($PSGalleryInstallationPolicy -eq 'Trusted') {
    Write-Output "PSGallery InstallationPolicy : Trusted"
}

# Checking PowerShell 5 Modules
Write-Output "Checking Legacy PowerShell5 Modules"
$Pwsh5Modules = @(
    'PackageManagement',
    'PowerShellGet',
    'PSReadLine'
)

ForEach ($Module in $Pwsh5Modules) {
    Write-Output "Checking PowerShell Module [ $Module ] version"
    $ModuleVersion = (Find-Module -Repository 'PSGallery' -Name $Module).Version 
    If ((Get-ChildItem -Path $env:ProgramFiles\WindowsPowerShell\Modules\$Module).Name -notcontains $ModuleVersion.ToString()) {
        Write-Output "Downloading $Module version: $ModuleVersion to $env:ProgramFiles\WindowsPowerShell\Modules\$Module"
        Save-Module -Repository 'PSGallery' -Name $Module -Path $env:ProgramFiles\WindowsPowerShell\Modules -Force
    }
}

# Create Symbolic Link for PowerShell Modules from PowerShell 7 to PowerShell 5
If ((Get-Item -Path $("$([Environment]::GetFolderPath("MyDocuments"))\WindowsPowerShell")).LinkType -eq $Null) {
    Write-Warning "Moving WindowsPowerShell to WindowsPowerShell.Old and creating SymbolicLink from $([Environment]::GetFolderPath("MyDocuments"))\PowerShell"
    Move-Item -Path "$([Environment]::GetFolderPath("MyDocuments"))\WindowsPowerShell" -Destination "$([Environment]::GetFolderPath("MyDocuments"))\WindowsPowerShell.Old" 
    New-Item -ItemType SymbolicLink -Target "$([Environment]::GetFolderPath("MyDocuments"))\PowerShell\" -Path "$([Environment]::GetFolderPath("MyDocuments"))\WindowsPowerShell\" | Out-Null
    Write-Output "Created Symbolic Link Target"
}

Write-Output `r "Checking PowerShell Modules"
# Install PowerShell Modules
$Pwsh7Modules = @(
    'Posh-Git',
    'Az'
)

ForEach ($Module in $Pwsh7Modules) {
    Write-Output "Checking PowerShell Module [ $Module ] version"
    $ModuleVersion = (Find-Module -Repository 'PSGallery' -Name $Module).Version 
    If ((Get-ChildItem -Path "$([Environment]::GetFolderPath("MyDocuments"))\PowerShell\Modules\$Module" -ErrorAction SilentlyContinue).Name -notcontains $ModuleVersion.ToString()) {
        Write-Output "Downloading $Module version: $ModuleVersion to $env:ProgramFiles\WindowsPowerShell\Modules\$Module"
        Install-Module -Repository 'PSGallery' -Name $Module -Force
    }
}

# Install Winget Modules
Write-Output `r "Chekcing Winget Modules"
$WinGetModules = @(
    'JanDeDobbeleer.OhMyPosh',
    'Git.Git',
    'Microsoft.AzureCLI',
    'Kubernetes.kubectl',
    'Helm.Helm'
)

ForEach ($Module in $WinGetModules) {
    Write-Output "Checking Winget Module [ $Module ] version"
    $listResult = winget list --query $Module --exact
    $lastLine = $listResult[-1]
    # $lastLine

    If (!$lastLine.Contains($Module)) {
        Write-Output "Installing $Module..."
        winget install $Module --silent --exact

    }

    Else {
        Write-Output "$Module already installed, upgrading to latest version"
        winget upgrade --query $Module --silent --exact

    }
}


# Nerd Font Installation Variables
$NerdFontPackageName = 'CascadiaCode.zip'
$NerdFontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/$NerdFontPackageName"
$NerdFontName = 'CaskaydiaCoveNerdFont-Regular.ttf'
$FilePath = "$Env:Temp\$($NerdFontPackageName.TrimEnd('.zip'))\$NerdFontName"
$FontName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
$DestinationPath = "C:\Windows\Fonts\$FontName.ttf"

If (!(Test-Path -Path $DestinationPath)) {

    # Verbose
    Write-Output `r "Starting Installation of Nerd Font [ $($NerdFontPackageName.Trim('.zip')) ]"

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
If (!(Test-Path -Path C:\Code)) {
    New-Item -ItemType 'Directory' -Path C:\Code
}

# Configure Windows Terminal 
$TerminalProfileConfig = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$TerminalProfileContent = Get-Content $TerminalProfileConfig
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
$TerminalProfileContent | Set-Content $TerminalProfileConfig

# Download Custom Oh-My-Posh Profile (Github Gist)
Write-Output "Downloading Oh-My-Posh Profile Json"
$PoshProfileGistUrl = "https://gist.githubusercontent.com/smoonlee/437a1a69a658a704928db5e8bd13a5b5/raw/e6e4e743bb0f743da18baf732e3bce4dc33757b9/quick-term-smoon.omp.json"
$PoshProfileName = Split-Path -Path $PoshProfileGistUrl -Leaf
Invoke-WebRequest -Uri $PoshProfileGistUrl -OutFile "$env:POSH_THEMES_PATH\$PoshProfileName"

# Configure Windows Terminal Font
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

$PSProfileConfig = $PSProfileConfig -f $PoshProfileName
$PSProfilePath = "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.PowerShell_profile.ps1"
$PSProfileConfig | Set-Content -Path $PSProfilePath -Force

$MasterProfile = "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.PowerShell_profile.ps1" # PowerShell 7 Profile
$Pwsh5Profile = "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" # PowerShell 5 Profile
$PwshVSCodeProfile = "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Microsoft.VSCode_profile.ps1" # VSCode Profile

# Create Symbolic Links
Write-Output "Creating Synbolic Links for PowerShell 5 and VSCode Profiles"
If (!(Test-Path $Pwsh5Profile)) {
    New-Item -ItemType SymbolicLink -Path $Pwsh5Profile -Target $MasterProfile -Force | Out-Null
    Write-Output "Created $Pwsh5Profile"
}

If (!(Test-Path $PwshVSCodeProfile)) {
    New-Item -ItemType SymbolicLink -Path $PwshVSCodeProfile -Target $MasterProfile -Force | Out-Null
    Write-Output "Created $PwshVSCodeProfile"
}

# Reload Shell Window
. $PSProfilePath

#
Write-Output "PSProfile Setup, Completed"
