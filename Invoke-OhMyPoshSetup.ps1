<#






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
    $licenseAsset = $latestRelease.assets | Where-Object name -like '*.xml'        | Select-Object -First 1

    if (-not $installerAsset -or -not $licenseAsset) {
        Write-Error "Failed to locate installer or license asset in the release."
        return
    }

    $downloadLinks[$installerAsset.name] = $installerAsset.browser_download_url
    $downloadLinks[$licenseAsset.name] = $licenseAsset.browser_download_url

    Write-Output "→ Downloading and installing WinGet dependencies..."

    foreach ($entry in $downloadLinks.GetEnumerator()) {
        $fileName = $entry.Key
        $url = $entry.Value
        $tempPath = Join-Path $env:TEMP $fileName

        Write-Output "Downloading $fileName..."
        try {
            Invoke-WebRequest -Uri $url -OutFile $tempPath -UseBasicParsing
        }
        catch {
            Write-Error "Failed to download $(fileName): $_"
            continue
        }

        if ($fileName -like '*.appx') {
            $localVersion = (Get-AppxPackage -Name 'Microsoft.VCLibs*' | Sort-Object -Property Version | Select-Object -Last 1).Version
            $fileVersion = (Get-AppPackageManifest -PackagePath $tempPath).Package.Properties.Version

            if ($localVersion -lt $fileVersion) {
                Write-Output "Installing $fileName..."
                Add-AppxPackage -Path $tempPath
            }
            else {
                Write-Warning "$fileName is older or already installed. Skipping."
            }

            Remove-Item -Path $tempPath -Force
        }
    }

    # Install App Installer MSIX and license
    $installerPath = Join-Path $env:TEMP $installerAsset.name
    $licensePath = Join-Path $env:TEMP $licenseAsset.name

    if (Test-Path $installerPath -and Test-Path $licensePath) {
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
        Write-Output "Refreshing WinGet sources..."
        Start-Process -FilePath $wingetExe -ArgumentList 'source reset --force' -Wait -NoNewWindow
        Start-Process -FilePath $wingetExe -ArgumentList 'source update' -Wait -NoNewWindow
    }
    else {
        Write-Warning "Cannot find winget.exe in expected location."
    }

    Write-Output "WinGet setup/update complete."
}

function Install-WinGetApplications {

    #
    # Windows Application
    #

    Write-Output `r "--> Installing Windows Applications"

    #
    $appList = @(
        'JanDeDobbeleer.OhMyPosh'
        'Microsoft.WindowsTerminal'
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

    Write-Output "Installing: Microsoft.AzureCLI Bicep"
    az bicep install
}

function Install-PwshModules {

    #
    # PowerShell Modules
    #

    Write-Output `r "--> Installing PowerShell Modules"

    Write-Output "Checking PSGallery InstallationPolicy"
    $policyState = (Get-PSRepository -Name 'PSGallery').InstallationPolicy
    if ($policyState -ne 'Trusted') {
        Write-Output "Updated PSGalery InstallationPolicy [Trusted]"
        Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' `r
    }
    else {
        Write-Output "PSGallery Installation Already Configured - [Trusted]" `r
    }

    if ($PSVersionTable.PSVersion.Major -eq '5') {

        #
        Write-Warning "PowerShell 5.x Detected, Updating Pester, PSReadLine, PowerShellGet, PackageManagement"

        #
        Write-Output "Installing Latest NuGet PackageProvider"
        Install-PackageProvider -Name 'NuGet' -Force | Out-Null

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
    Write-Output `r "--> Configuring Windows Terminal Profile"

    # Check if WSL is enabled
    Write-Output "Checking for Windows Subsystem for Linux (WSL) support..."
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

    if ($wslFeature.State -eq "Enabled") {
        Write-Output "Microsoft-Windows-Subsystem-Linux is already enabled."
    } else {
        Write-Output "WSL is not enabled. Enabling WSL..."
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
        Write-Output "WSL has been enabled. Please restart your computer to apply the changes."
    }

    # Check if Ubuntu 24.04 is already installed
    $wslDistro = "Ubuntu-24.04"
    $installedDistros = wsl.exe --list --quiet

    if ($installedDistros -contains $wslDistro) {
        Write-Output "The WSL instance '$wslDistro' is already installed. Skipping installation."
    } else {
        Write-Output "Installing: $wslDistro"
        wsl.exe --install $wslDistro
    }

    #
    Write-Output `r "Downloading Windows Terminal Profile Settings..."

    $apiUrl = 'https://api.github.com/repos/smoonlee/oh-my-posh-profile/contents/windows-terminal-settings.json?ref=main'
    $response = Invoke-RestMethod -Method 'Get' -Uri $apiUrl

    # Decode base64 content and write to file
    $contentBytes = [System.Convert]::FromBase64String($response.content)
    [System.IO.File]::WriteAllBytes($env:LOCALAPPDATA + "\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json", $contentBytes)

    Write-Output "Downloading Oh My Posh Profile..."
    $apiUrl = 'https://api.github.com/repos/smoonlee/oh-my-posh-profile/contents/quick-term-cloud.omp.json?ref=main'
    $response = Invoke-RestMethod -Method 'Get' -Uri $apiUrl

    # Decode base64 content and write to file
    $contentBytes = [System.Convert]::FromBase64String($response.content)
    [System.IO.File]::WriteAllBytes("$env:POSH_THEMES_PATH\quick-term-cloud.omp.json", $contentBytes)
   
    Write-Output "Downloading PowerShell Profile..."
    $apiUrl = 'https://api.github.com/repos/smoonlee/oh-my-posh-profile/contents/Microsoft.PowerShell_profile.ps1?ref=main'
    $response = Invoke-RestMethod -Method 'Get' -Uri $apiUrl

    # Decode base64 content and write to file
    $contentBytes = [System.Convert]::FromBase64String($response.content)
    [System.IO.File]::WriteAllBytes("C:\Users\Simon\Documents\PowerShell\Microsoft.PowerShell_profile.ps1", $contentBytes)
   


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
    Write-Output `r "--> Reloading PowerShell Profile!"

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
