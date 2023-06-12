Param (
    [switch]$InstallNerdFont,
    [switch]$ResetProfile
)

# Welcome Message
Write-Output "=================================================="
Write-Output "    Welcome to the PS Profile Installer [2.0]     "
Write-Output "=================================================="

$MasterProfile = "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.PowerShell_profile.ps1" # PowerShell 7 Profile
$Pwsh5Profile = "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" # PowerShell 5 Profile
$PwshVSCodeProfile = "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Microsoft.VSCode_profile.ps1" # VSCode Profile

# Remove Old Profile Config Files
if ($ResetProfile) {
    Write-Warning "Resetting PSProfile, removing all existing profile files"

    $profiles = @($MasterProfile, $Pwsh5Profile, $PwshVSCodeProfile)
    foreach ($profile in $profiles) {
        if (Test-Path -Path $profile -ErrorAction SilentlyContinue) {
            Remove-Item -Path $profile -Force
            Write-Output "Removed $profile"
        }
    }
}


If ($InstallNerdFont) {
    # Download and Install Nerd Font
    $NerdFontPackageName = 'CascadiaCode.zip'
    $NerdFontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.1/$NerdFontPackageName"

    Write-Output "Downloading Nerd Font: $($NerdFontPackageName.TrimEnd('.zip'))"
    Invoke-WebRequest -Uri $NerdFontUrl -OutFile "$Env:Temp\$NerdFontPackageName"

    # Extract Nerd Font
    Write-Output "Extracting: $($NerdFontPackageName.TrimEnd('.zip'))"
    Expand-Archive -Path "$Env:Temp\$NerdFontPackageName" -DestinationPath "$Env:Temp\$($NerdFontPackageName.TrimEnd('.zip'))" -Force

    # Install Nerd Font
    $NerdFontName = 'CaskaydiaCoveNerdFont-Regular.ttf'
    $FilePath = "$Env:Temp\$($NerdFontPackageName.TrimEnd('.zip'))\$NerdFontName"
    $FontName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    $DestinationPath = "C:\Windows\Fonts\$FontName.ttf"

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

    # Verify Nerd Font Installed
    if (Test-Path -Path $DestinationPath) {
        Write-Output "$NerdFontName : Installed" `r
    }
}

# Install Oh-My-Posh, Git, and Azure CLI
$wingetArgs = @(
    @{ Name = 'JanDeDobbeleer.OhMyPosh'; Description = 'Oh-My-Posh'; },
    @{ Name = 'Git.Git'; Description = 'Git'; },
    @{ Name = 'Microsoft.AzureCLI'; Description = 'Microsoft Azure CLI'; }
    @{ Name = 'Kubernetes.kubectl'; Description = 'Kubectl'; }
)

foreach ($App in $wingetArgs) {
    If (!(winget.exe -list $App)) {
        Write-Output "Installing $($app.Description) (WinGet)"
        Start-Process -Wait -NoNewWindow -FilePath 'winget.exe' -ArgumentList "install $($app.Name) --accept-source-agreements --accept-package-agreements"
    }
}

# Download PowerShell Modules
$modules = @('Posh-Git','Az')
foreach ($module in $modules) {
    if (!(Get-Module -ListAvailable -Name $module)) {
    Write-Output "Downloading Module: $module"
    Save-Module -Name $module -Path 'C:\Program Files\WindowsPowerShell\Modules' -Force
    }
}

if ((Get-InstalledModule -Name 'PSReadLine' -ErrorAction SilentlyContinue).Version -lt '2.1.0') {
    Save-Module -Name 'PSReadLine' -MinimumVersion '2.1.0' -Path 'C:\Program Files\WindowsPowerShell\Modules' -Force
}

# Configure Windows Terminal Profile
Write-Output `r "Configuring Windows Terminal Profile"

# Create Code Folder
If (!(Test-Path -Path C:\Code)) {
New-Item -ItemType Directory -Path C:\Code | Out-Null
Write-Output "Created C:\Code"
}

# Terminal Config
$TerminalProfileConfig = "C:\Users\$Env:USERNAME\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
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
$PoshProfileGistUrl = "https://gist.githubusercontent.com/smoonlee/437a1a69a658a704928db5e8bd13a5b5/raw/8e45860da5fa66a57a6852f95f8892181340b07a/quick-term-smoon.omp.json"
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
