<#
.SYNOPSIS
    Automates the setup and configuration of a Windows development environment, including package installations, PowerShell modules, fonts, and terminal profiles.

.DESCRIPTION
    This script performs the following tasks:
    - Checks and updates the WinGet CLI Package Manager.
    - Installs a predefined list of Windows applications using WinGet.
    - Installs and updates PowerShell modules from PSGallery.
    - Downloads and installs a specified Nerd Font.
    - Configures the Windows Terminal profile, including WSL setup and profile customization.
    - Sets up cross-version PowerShell module support between PowerShell 5.x and 7.x.
    - Patches the VSCode PowerShell extension to resolve compatibility issues with PSReadLine.
    - Reloads the PowerShell profile to apply changes.

.PARAMETER nerdFont
    Specifies the name of the Nerd Font to be installed. Default is 'CascadiaCode'.

.NOTES
    - Requires administrative privileges to run.
    - Designed for Windows environments with PowerShell 5.x or later.
    - Internet connectivity is required for downloading packages and resources.

.EXAMPLE
    .\Setup-Script.ps1 -nerdFont 'FiraCode'
    Runs the script and installs the 'FiraCode' Nerd Font along with other configurations.

.EXAMPLE
    .\Setup-Script.ps1
    Runs the script with the default Nerd Font ('CascadiaCode').

.REQUIREMENTS
    - PowerShell 5.x or later.
    - Administrative privileges.
    - Internet connectivity.

.AUTHOR
    Simon Lee

.VERSION
    3.2.0

.LINK
    https://github.com/smoonlee/oh-my-posh-profile
#>

#Requires -RunAsAdministrator

param (
    [Parameter(Mandatory = $false)]
    [string]$nerdFont = 'CascadiaCode'
)

function Invoke-WinGetPackageCheck {
    Write-Output "--> Checking WinGet CLI Package Manager"

    $wingetReleaseUrl = 'https://api.github.com/repos/microsoft/winget-cli/releases/latest'

    try {
        $latestRelease = Invoke-RestMethod -Method 'Get' -Uri $wingetReleaseUrl
        $latestVersion = $latestRelease.tag_name.TrimStart("v")
    }
    catch {
        Write-Error "Failed to retrieve latest WinGet release info: $_"
        return
    }

    $localVersion = (winget --version) -replace '[^\d.]', ''

    if ($localVersion -eq $latestVersion) {
        Write-Output "WinGet CLI is up to date: $localVersion"
        return
    }

    Write-Warning "WinGet CLI needs updating: Local=$localVersion, Latest=$latestVersion"

    # Define download URLs
    $downloadLinks = @{
        'Microsoft.VCLibs.x64.appx' = 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
        'Microsoft.VCLibs.x86.appx' = 'https://aka.ms/Microsoft.VCLibs.x86.14.00.Desktop.appx'
    }

    # Get asset URLs for App Installer bundle and license from GitHub release
    $installerAsset = $latestRelease.assets | Where-Object name -like '*.msixbundle' | Select-Object -First 1
    $licenseAsset = $latestRelease.assets | Where-Object name -like '*.xml' | Select-Object -First 1

    if (-not $installerAsset -or -not $licenseAsset) {
        Write-Error "Failed to locate installer or license asset in the release."
        return
    }

    $downloadLinks[$installerAsset.name] = $installerAsset.browser_download_url
    $downloadLinks[$licenseAsset.name] = $licenseAsset.browser_download_url

    Write-Output `r "--> Downloading Microsoft.VCLibs dependencies..."

    $tempFiles = @{}

    foreach ($lib in @('Microsoft.VCLibs.x64.appx', 'Microsoft.VCLibs.x86.appx')) {
        $url = $downloadLinks[$lib]
        $tempPath = Join-Path $env:TEMP $lib

        Write-Output "Downloading: $lib..."
        try {
            Invoke-WebRequest -Uri $url -OutFile $tempPath -UseBasicParsing
            $tempFiles[$lib] = $tempPath
        }
        catch {
            Write-Error "Failed to download $($lib): $_"
            return
        }
    }

    # Install VCLibs if needed
    foreach ($lib in $tempFiles.Keys) {
        $tempPath = $tempFiles[$lib]
        try {
            $fileVersion = (Get-AppPackageManifest -Package $tempPath).Package.Properties.Version

            $arch = if ($lib -like '*x64*') { 'X64' } else { 'X86' }
            $localVersion = Get-AppxPackage | Where-Object {
                $_.Name -match 'Microsoft\.VCLibs\.140\.00\.UWPDesktop' -and $_.Architecture -eq $arch
            } | Sort-Object Version | Select-Object -ExpandProperty Version -Last 1

            if (-not $localVersion) {
                Write-Output "$lib not found locally. Installing version $fileVersion..."
                Add-AppxPackage -Path $tempPath
            }
            elseif ([version]$fileVersion -gt [version]$localVersion) {
                Write-Output "$lib local version: $localVersion, available: $fileVersion — Updating..."
                Add-AppxPackage -Path $tempPath
            }
            else {
                Write-Output "$lib local version: $localVersion, available: $fileVersion — Up-to-date or newer, skipping."
            }
        }
        catch {
            Write-Error "Failed to evaluate/install $($lib): $_"
        }
        finally {
            Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
        }
    }

    # Install App Installer MSIX and license
    Write-Output `r "--> Installing App Installer and license..."

    $installerPath = Join-Path $env:TEMP $installerAsset.name
    $licensePath = Join-Path $env:TEMP $licenseAsset.name

    try {
        Write-Output "Downloading: $($installerAsset.name)..."
        Invoke-WebRequest -Uri $installerAsset.browser_download_url -OutFile $installerPath -UseBasicParsing

        Write-Output "Downloading: $($licenseAsset.name)..."
        Invoke-WebRequest -Uri $licenseAsset.browser_download_url -OutFile $licensePath -UseBasicParsing
    }
    catch {
        Write-Error "Failed to download App Installer bundle or license: $_"
        return
    }

    if ((Test-Path $installerPath) -and (Test-Path $licensePath)) {
        Write-Output "Installing App Installer ($($installerAsset.name))..."
        Add-AppProvisionedPackage -Online -PackagePath $installerPath -LicensePath $licensePath | Out-Null
        Remove-Item $installerPath, $licensePath -Force
    }
    else {
        Write-Error "Installer or license file missing, skipping provisioning."
    }

    # Refresh WinGet sources
    $wingetExe = "$env:LOCALAPPDATA\Microsoft\WindowsApps\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\winget.exe"
    if (Test-Path $wingetExe) {
        Write-Output `r "Refreshing WinGet sources..."
        Start-Process -FilePath $wingetExe -ArgumentList 'source reset --force' -Wait -NoNewWindow
        Start-Process -FilePath $wingetExe -ArgumentList 'source update' -Wait -NoNewWindow
    }
    else {
        Write-Warning "Cannot find winget.exe in expected location."
    }

    Write-Output `r "WinGet CLI Package Manager Updated!"
}

function Install-WinGetApplications {

    #
    # Windows Application
    #

    Write-Output `r "--> Installing Windows Applications"

    #
    $appList = @(
        'Microsoft.WindowsTerminal'
        'JanDeDobbeleer.OhMyPosh'
        'Microsoft.PowerShell'
        'Microsoft.VisualStudioCode.CLI'
        'Microsoft.AzureCLI'
        'Microsoft.Azure.Kubelogin'
        'Amazon.AWSCLI'
        'Hashicorp.Terraform'
        'Git.Git'
        'GitHub.cli'
        'Helm.Helm'
        'Kubernetes.kubectl'
        'FireDaemon.OpenSSL'
        'Ookla.Speedtest.CLI'
    )

    foreach ($app in $appList) {
        Write-Output "Installing: $app"
        winget install  --accept-source-agreements --accept-source-agreements --scope machine --silent --exact --id $app | Out-Null
    }

    # Install Azure CLI Bicep Extension
    Write-Output "Installing: Azure CLI Bicep Extension"
    . "C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd" bicep install | Out-Null
}

function Install-PwshModules {

    #
    # PowerShell Modules
    #

    Write-Output `r "--> Installing PowerShell Modules"

    Write-Output "Checking PSGallery InstallationPolicy"

    #
    if ($PSVersionTable.PSVersion.Major -eq '5') {
        Write-Output "Installing Latest NuGet PackageProvider"
        Install-PackageProvider -Name 'NuGet' -Force | Out-Null
    }

    $policyState = (Get-PSRepository -Name 'PSGallery').InstallationPolicy
    if ($policyState -ne 'Trusted') {
        Write-Output "Updated PSGalery InstallationPolicy [Trusted]" `r
        Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted'
    }
    else {
        Write-Output "PSGallery Installation Already Configured - [Trusted]" `r
    }

    if ($PSVersionTable.PSVersion.Major -eq '5') {

        #
        Write-Warning "PowerShell 5.x Detected, Updating Pester, PSReadLine, PowerShellGet, PackageManagement"

        $pwsh5Modules = @(
            'PowerShellGet'
            'PackageManagement'
            'Pester'
            'PSReadLine'
        )

        foreach ($module in $pwsh5Modules) {
            $onlineModule = Find-Module -Repository 'PSGallery' -Name $module
            $moduleCheck = Get-Module -ListAvailable -Name $module
            if ($moduleCheck) {
                $localModuleVersion = $(Get-Module -ListAvailable -Name $module | Select-Object 'Version' -First 1).Version.ToString()
            }

            if ($onlineModule.version -eq $localModuleVersion) {
                Write-Output "Module: $module is up to date"
            }

            if ($onlineModule.version -ne $localModuleVersion) {
                Write-Output "Installing Module: $module"
                Install-Module -Repository 'PSGallery' -Scope 'CurrentUser' -Name $module -AllowClobber -SkipPublisherCheck -Force
                Import-Module -Name $module
            }
        }

        #
        Write-Output ""
    }

    $pwshModules = @(
        'Az'
        'Microsoft.Graph'
        'Terminal-Icons'
        'Posh-Git'
        'Pester'
        'PSReadLine'
    )

    foreach ($module in $pwshModules) {
        $onlineModule = Find-Module -Repository 'PSGallery' -Name $module
        $moduleCheck = Get-Module -ListAvailable -Name $module
        if ($moduleCheck) {
            $localModuleVersion = $(Get-Module -ListAvailable -Name $module | Select-Object 'Version' -First 1).Version.ToString()
        }

        if ($onlineModule.version -eq $localModuleVersion) {
            Write-Output "Module: $module is up to date"
        }

        if ($onlineModule.version -ne $localModuleVersion) {
            Write-Output "Installing Module: $module"
            Install-Module -Repository 'PSGallery' -Scope 'CurrentUser' -Name $module -Force -WarningAction Ignore
        }

        if ($module -eq 'PSReadLine' -or $module -eq 'Pester') {
            Save-Module -Name $module -Path 'C:\Program Files\WindowsPowerShell\Modules'
        }

    }

}

function Install-NerdFontPackage {
    param (
        [Parameter(Mandatory = $true)]
        [string]$nerdFont
    )

    Write-Output `r "--> Installing NerdFont: $nerdFont"

    $repoApiUrl = "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest"

    if (Get-ChildItem -Path C:\Windows\Fonts | Where-Object 'Name' -like "*NerdFont-Regular.ttf") {
        Write-Output "Nerd Font [$nerdFont] is already installed"
        return
    }

    try {
        Write-Output "Fetching latest Nerd Fonts release info..."
        $releaseInfo = Invoke-RestMethod -Uri $repoApiUrl -UseBasicParsing

        $asset = $releaseInfo.assets | Where-Object { $_.name -match "^$nerdFont\.zip$" }

        if (-not $asset) {
            Write-Error "Font '$nerdFont' not found in the latest release."
            return
        }

        $tempZip = Join-Path $env:TEMP "$nerdFont.zip"
        $extractPath = Join-Path $env:TEMP "$nerdFont-Font"

        $fileSizeMB = [math]::Round($asset.size / 1MB, 2)
        Write-Output "Downloading $nerdFont.zip (${fileSizeMB} MB)..."
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempZip -UseBasicParsing

        Write-Output "Extracting font files..."
        Expand-Archive -LiteralPath $tempZip -DestinationPath $extractPath -Force

        $fonts = Get-ChildItem -Path $extractPath -Include *NerdFont-Regular*.ttf, *.otf -Recurse

        if (-not $fonts) {
            Write-Error "No font files found in the downloaded archive."
            return
        }

        $fontDir = "$env:WINDIR\Fonts"
        $fontRegistryPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

        foreach ($font in $fonts) {
            $destination = Join-Path $fontDir $font.Name
            if (-not (Test-Path $destination)) {
                Copy-Item -Path $font.FullName -Destination $destination -Force

                # Add registry entry for the font
                $fontName = $font.BaseName
                $registryName = "$fontName (TrueType)"
                $registryValue = $font.Name

                New-ItemProperty -Path $fontRegistryPath -Name $registryName -PropertyType String -Value $registryValue -Force | Out-Null
            }

            Write-Output "$($fonts.Count) font file(s) installed to $fontDir"
        }

        # Cleanup
        Write-Output "Cleaning up temporary files..."
        Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue

        Write-Output "Installation complete."
    }
    catch {
        Write-Error "An error occurred: $_"
    }
}

function Set-WindowsTerminalProfile {

    # Import DISM Module
    Import-Module -Name 'DISM'

    Write-Output `r "--> Configuring Windows Terminal Profile"

    # Check if WSL is enabled
    Write-Output "Checking for Windows Subsystem for Linux (WSL) support..."
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

    if ($wslFeature.State -eq "Enabled") {
        Write-Output "Microsoft-Windows-Subsystem-Linux is already enabled."
    }
    else {
        Write-Output "WSL is not enabled. Enabling WSL..."
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
        Write-Output "WSL has been enabled. Please restart your computer to apply the changes."
    }

    # Check if Ubuntu 24.04 is already installed
    $wslDistro = "Ubuntu-24.04"
    $installedDistros = wsl.exe --list --quiet

    if ($installedDistros -contains $wslDistro) {
        Write-Output "The WSL instance '$wslDistro' is already installed. Skipping installation."
    }
    else {
        Write-Output `r "Installing: $wslDistro"
        wsl.exe --install $wslDistro
    }

    #
    Write-Output `r "Downloading Windows Terminal Profile Settings..."

    $apiUrl = 'https://api.github.com/repos/smoonlee/oh-my-posh-profile/contents/windows-terminal-settings.json?ref=main'
    $response = Invoke-RestMethod -Method 'Get' -Uri $apiUrl

    # Decode base64 content and write to file
    $contentBytes = [System.Convert]::FromBase64String($response.content)
    [System.IO.File]::WriteAllBytes("$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json", $contentBytes)

    Write-Output "Downloading Oh My Posh Profile..."
    $apiUrl = 'https://api.github.com/repos/smoonlee/oh-my-posh-profile/contents/quick-term-cloud.omp.json?ref=main'
    $response = Invoke-RestMethod -Method 'Get' -Uri $apiUrl

    # Decode base64 content and write to file
    $env:Path += ";C:\Program Files (x86)\oh-my-posh\bin"
    $contentBytes = [System.Convert]::FromBase64String($response.content)
    [System.IO.File]::WriteAllBytes("$env:POSH_THEMES_PATH\quick-term-cloud.omp.json", $contentBytes)

    Write-Output "Downloading PowerShell Profile..."
    $apiUrl = 'https://api.github.com/repos/smoonlee/oh-my-posh-profile/contents/Microsoft.PowerShell_profile.ps1?ref=main'
    $response = Invoke-RestMethod -Method 'Get' -Uri $apiUrl

    # Decode base64 content and write to file
    $contentBytes = [System.Convert]::FromBase64String($response.content)
    [System.IO.File]::WriteAllBytes("$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.PowerShell_profile.ps1", $contentBytes)

    $codePath = 'C:\Code'
    If (!(Test-Path -Path $codePath)) {
        #
        Write-Output "Creating Local Code Folder: $codePath"

        New-Item -ItemType 'Directory' -Path $codePath | Out-Null
    }
}

function Set-CrossPlatformModuleSupport {
    Write-Output `r "--> PowerShell Module Cross Version Support"

    if ($host.Version.Major -eq '5') {
        if (Test-Path -Path "$env:UserProfile\Documents\PowerShell\Modules") {
            Remove-Item -Path "$env:UserProfile\Documents\PowerShell\Modules" -Recurse -Force
        }

        # Target - Source Folder # Path - Link Folder
        # PowerShell Module Link
        New-Item -ItemType 'SymbolicLink' -Target "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Modules" -Path "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Modules" -Force | Out-Null
        Write-Output "Symbolic Link Created from 'WindowsPowerShell' to 'PowerShell' Modules"

        # PowerShell Profile Link
        New-Item -ItemType 'SymbolicLink' -Target "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" -Path "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.PowerShell_profile.ps1" -Force | Out-Null
        Write-Output "Symbolic Link Created from 'WindowsPowerShell' to 'PowerShell' Profile"

        # VSCode Profile Link
        New-Item -ItemType 'SymbolicLink' -Target "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" -Path "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.VSCode_profile.ps1" -Force | Out-Null
        Write-Output "Symbolic Link Created from 'WindowsPowerShell' to 'VSCode' Profile"

    }

    if ($host.Version.Major -eq '7') {
        if (Test-Path -Path "$env:UserProfile\Documents\WindowsPowerShell\Modules" ) {
            Remove-Item -Path "$env:UserProfile\Documents\WindowsPowerShell\Modules" -Recurse -Force
        }

        # Target - Source Folder # Path - Link Folder
        # PowerShell Module Link
        New-Item -ItemType 'SymbolicLink' -Target "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Modules" -Path "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Modules" -Force | Out-Null
        Write-Output "Symbolic Link Created from 'PowerShell' to 'WindowsPowerShell' Modules"

        # PowerShell 5 Profile Link
        New-Item -ItemType 'SymbolicLink' -Target "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.PowerShell_profile.ps1" -Path "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" -Force | Out-Null
        Write-Output "Symbolic Link Created from 'PowerShell' to 'WindowsPowerShell' Profile"

        # VSCode Profile Link
        New-Item -ItemType 'SymbolicLink' -Target "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.PowerShell_profile.ps1" -Path "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.VSCode_profile.ps1" -Force | Out-Null
        Write-Output "Symbolic Link Created from 'PowerShell' to 'VSCode' Profile"
    }
    Write-Output "" # Required for script spacing
}

function Update-VSCodePwshModule {
    Write-Output "--> Patching VSCode PowerShell Module"
    $psReadLineVersion = $(Find-Module -Name 'PSReadLine' | Select-Object Version).version.ToString()
    $folderName = $(Get-ChildItem -Path "$env:UserProfile\.vscode\extensions" -ErrorAction SilentlyContinue | Where-Object 'Name' -like 'ms-vscode.powershell*').name | Select-Object -Last 1
    if ([string]::IsNullOrEmpty($folderName)) {
        Write-Output "VSCode PowerShell Module not found, Skipping patch!"
        return
    }
    $vsCodeModulePath = "$env:UserProfile\.vscode\extensions\$folderName"

    if (!(Get-ChildItem -Path $vsCodeModulePath\modules\PSReadLine | Where-Object 'Name' -like '2.3.6' )) {
        Write-Output "Checking if VSCode is running..."
        $vsCodeProcess = Get-Process -Name Code -ErrorAction SilentlyContinue
        if ($vsCodeProcess) {
            Write-Warning "Please close Visual Studio Code before continuing, Skipping VSCode PowerShell Module patch!!"
            return
        }

        Write-Output "VSCode not running, Patching PowerShell Module [$folderName]" `r
        Write-Output "The PowerShell Module Extension [$folderName], Uses PSReadline 2.4.0 Beta."
        Write-Output "Using 2.4.0 Beta you get this error: 'Assembly with same name is already loaded'"
        Write-Output "The OhMyPoshProfile setup scripts installs the latest stable version of PSReadline [$psReadLineVersion]"

        if (Test-Path -Path "$vsCodeModulePath\modules\PSReadLine\2.4.0" ) {
            Remove-Item -Path "$vsCodeModulePath\modules\PSReadLine\2.4.0" -Recurse -Force
        }

        # Check if 2.3.6 is not installed
        Save-Module -Name 'PSReadLine' -Path "$vsCodeModulePath\modules" -Force
    }
    else {
        Write-Output "VSCode PowerShell Module is already patched"
    }
}

function Register-PSProfile {

    #
    Write-Output `r "--> Reloading PowerShell Profile!" `r

    # https://stackoverflow.com/questions/11546069/refreshing-restarting-powershell-session-w-out-exiting
    Get-Process -Id $PID | Select-Object -ExpandProperty Path | ForEach-Object { Invoke-Command { & "$_" } -NoNewScope }
}

#
$timeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
Write-Output "#########################################"
Write-Output " Simon's Oh My Posh Profile Setup v3.2.0 "
Write-Output "#########################################"
Write-Output "Install Start Time: $timeStamp" `r

#
Invoke-WinGetPackageCheck

#
Install-WinGetApplications

#
Install-PwshModules

#
Install-NerdFontPackage -nerdFont $nerdFont

#
Set-WindowsTerminalProfile

#
Set-CrossPlatformModuleSupport

#
Update-VSCodePwshModule

#
Register-PSProfile
