<#


#>

#-Require -RunAsAdministrator

# Script Variables
$scriptVersion = 'v3'
$nerdFontFileName = 'CascadiaCode.zip'

function getSystemRequirements {

    Write-Output "[OhMyPoshProfile $scriptVersion] :: Oh My Posh - System Validation"
    Write-Output "[OhMyPoshProfile $scriptVersion] :: Checking VSCode Installation Location"
    $vscodeSystemPath = "C:\Program Files\Microsoft VS Code\Code.exe"
    $vscodeUserPath = "C:\Users\$env:USERNAME\AppData\Local\Programs\Microsoft VS Code\Code.exe"
    if (Test-Path $vscodeSystemPath) {
        Write-Output "[OhMyPoshProfile $scriptVersion] :: VSCode System Path: $vscodeSystemPath"
    }
    elseif (Test-Path $vscodeUserPath) {
        Write-Output "[OhMyPoshProfile $scriptVersion] :: VSCode User Path: $vscodeUserPath"
    }
    else {
        Write-Output "VSCode not found"
    }

    Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Checking PowerShell 7 Installation Location"
    $pwsh7SystemPath = "C:\Program Files\PowerShell\7\pwsh.exe"
    $pwsh7UserPath = "C:\Users\$env:USERNAME\AppData\Local\Microsoft\WindowsApps\pwsh.exe"
    if (Test-Path $pwsh7SystemPath) {
        Write-Output "[OhMyPoshProfile $scriptVersion] :: PowerShell 7 System Path: $pwsh7SystemPath"
        & $pwsh7SystemPath -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"
        Write-Output "[OhMyPoshProfile $scriptVersion] :: Updated Execution Policy for PowerShell 7 'RemoteSigned'"
    }   
    elseif (Test-Path $pwsh7UserPath) {
        Write-Output "[OhMyPoshProfile $scriptVersion] :: PowerShell 7 User Path: $pwsh7UserPath"
        & $pwsh7UserPath -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"
        Write-Output "[OhMyPoshProfile $scriptVersion] :: Updated Execution Policy for PowerShell 7 'RemoteSigned'"
    }
    else {
        Write-Output "PowerShell 7 not found"
    }

    $pwsh5SystemPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    & $pwsh5SystemPath -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"
    Write-Output "[OhMyPoshProfile $scriptVersion] :: Updated Execution Policy for PowerShell 5 'RemoteSigned'"

}

function installNerdFont {
    param (
        $nerdFontFileName 
    )

    # Get the latest release of Nerd Fonts
    $nerdFontGitHubUrl = 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases'
    $response = Invoke-WebRequest -Uri $nerdFontGitHubUrl
    $releases = $response.Content | ConvertFrom-Json
    $latestRelease = $releases[0]
    $nerdFont = $latestRelease.assets | Where-Object { $_.name -like $nerdFontFileName }

    Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Checking for Nerd Font [$nerdFontFileName]"

    $windowsFontPath = 'C:\Windows\Fonts'
    if (Get-ChildItem -Path C:\Windows\Fonts | Where-Object 'Name' -like "*NerdFont-Regular.ttf") {
        Write-Output "[OhMyPoshProfile $scriptVersion] :: Nerd Font [$nerdFontFileName] is already installed"
    }
    
    if (!(Get-ChildItem -Path C:\Windows\Fonts | Where-Object 'Name' -like "*NerdFont-Regular.ttf")) {
        # Download Nerd Font
        Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Nerd Font [$nerdFontFileName] Download"
        $nerdFontZipName = $nerdFont.name
        $folderName = $nerdFontFileName.Replace('.zip', '')

        $downloadUrl = $nerdFont.browser_download_url
        $outFile = "$Env:Temp\$nerdFontZipName"
        $wc = New-Object net.webclient
        $wc.downloadFile($downloadUrl, $outFile) 
    
        Expand-Archive -Path $outFile -DestinationPath $Env:Temp\$folderName

        # Install Nerd Font
        Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Nerd Font [$nerdFontFileName] Install"
        $fontFile = Get-ChildItem -Path $Env:Temp\$folderName | Where-Object 'Name' -like "*NerdFont-Regular.ttf"
        Copy-Item -Path "$Env:Temp\$folderName\$($fontFile.Name)" -Destination 'C:\Windows\Fonts'
    
        $fontRegistryPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
        $fontEntry = $fontFile.Name # Modify this if the font is not TrueType
        $dataValue = "C:\Windows\Fonts\$($fontFile.Name)"
        New-ItemProperty -Path $fontRegistryPath -Name $fontEntry -PropertyType String -Value $dataValue -Force | Out-Null

        $wshShell = New-Object -ComObject WScript.Shell
        $fontCachePath = "$env:SystemRoot\System32\FNTCACHE.DAT"
        $wshShell.AppActivate('Font Viewer') | Out-Null
        Start-Sleep -Milliseconds 500
        $wshShell.SendKeys('{F5}')
        Start-Sleep -Milliseconds 500
        $wshShell.SendKeys('{TAB}{ENTER}')
        Start-Sleep -Milliseconds 500

        if (Test-Path $fontCachePath) {
            Remove-Item $fontCachePath -Force
        }

        # Remove Zip Font Folder
        Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Cleaning Up Nerd Font [$nerdFontFileName]"
        Remove-Item -Path $outFile -Force 
        Remove-Item -Path "$Env:Temp\$folderName" -Recurse -Force
    }
}

function installPowerShellModules {
    Write-Output `r "[OhMyPoshProfile $scriptVersion] :: PowerShell Module Installation"

    $coreModules = @('PackageManagement', 'PowerShellGet')
    forEach ($module in $coreModules) {
        Write-Output "[OhMyPoshProfile $scriptVersion] :: Installing Core PowerShell Module [$module]"
        Install-Module -Repository 'PSGallery' -Scope 'AllUsers' -Name $module -Force
    }

    # Set PSGallery as a trusted repository
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted'

    $pwshModule = @( 
        'Az'
        'Posh-Git',
        'Terminal-Icons',
        'PSReadLine',
        'Pester'
    )

    forEach ($module in $pwshModule) {
        Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Checking PowerShell Module [$module]"
        $onlineModule = Find-Module -Repository 'PSGallery' -Name $module 
        $localModule = Get-Module -ListAvailable -Name $module

        if ($onlineModule.version -eq $localModule.version) {
            Write-Output "[OhMyPoshProfile $scriptVersion] :: PowerShell Module [$module] is up to date"
        }
        
        if ($onlineModule.version -ne $localModule.version) {
            Write-Output "[OhMyPoshProfile $scriptVersion] :: Installing PowerShell Module [$module]"
            Install-Module -Repository 'PSGallery' -Scope 'CurrentUser' -Name $module  -Force
        }

        if ($module -eq 'PSReadLine') {
            Save-Module -Name $module -Path 'C:\Program Files\WindowsPowerShell\Modules'
        }
    }
}

function installWinGetApplications {

    # Configure WinGet 
    Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Checking Winget Modules"
    $winGetApps = @(
        'JanDeDobbeleer.OhMyPosh',
        'Git.Git',
        'GitHub.cli',
        'Microsoft.AzureCLI',
        'Microsoft.Azure.Kubelogin',
        'Kubernetes.kubectl',
        'Helm.Helm'
    )

    ForEach ($app in $winGetApps) {
        Write-Output "[OhMyPoshProfile $scriptVersion] :: Checking for [$app]"

        $appCheck = winget.exe list --exact --query $app --accept-source-agreements
        If ($appCheck[-1] -notmatch $app) {
            Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Installing [$app]"
            winget.exe install --silent --exact --query $app --accept-source-agreements
            Write-Output "" # Required for script spacing
        }
    }

}

function setPwshProfile {
    Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Downloading Oh-My-Posh Profile: [quick-term-smoon]"
    $poshThemeUrl = "https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile/main/quick-term-smoon.omp.json"
    $poshThemeName = Split-Path -Path $poshThemeUrl -Leaf
    Invoke-WebRequest -Uri $poshThemeUrl -OutFile "$Env:LOCALAPPDATA\Programs\oh-my-posh\themes\$poshThemeName"

    Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Creating PowerShell Profile"

    if ($host.version.Major -eq '7') {
        $pwshProfilePath = "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.PowerShell_profile.ps1"
        $pwshProfile = @'
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

(@(& "$Env:LOCALAPPDATA\Programs\oh-my-posh\bin\oh-my-posh.exe" init pwsh --config="$Env:LOCALAPPDATA\Programs\oh-my-posh\themes\{0}" --print) -join "`n") | Invoke-Expression

# Oh-My-Posh Configuration
$env:POSH_AZURE_ENABLED = $true
$env:POSH_GIT_ENABLED = $true
'@ 

        $pwshProfile = $pwshProfile -f $poshThemeName 
        $pwshProfile | Set-Content -Path $pwshProfilePath -Force

    }

    if ($host.version.major -eq '5') {
        $pwshProfilePath = "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"

    }


    . $PROFILE

}

function setWindowsTerminal {
    Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Updating Windows Terminal Configuration"

    $settingJsonUrl = "https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile/main/settings.json"
    $localSettingsPath = "$Env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    Invoke-WebRequest -Uri $settingJsonUrl -OutFile $localSettingsPath
}

function setCrossPlatformModuleSupport {
    Write-Output `r "[OhMyPoshProfile $scriptVersion] :: PowerShell Module Cross Version Support"

    if ($host.Version.Major -eq '5') {
        if (Test-Path -Path $Env:UserProfile\Documents\PowerShell\Modules) {
            Remove-Item -Path "$Env:UserProfile\Documents\PowerShell\Modules" -Recurse -Force
        }
        
        # Target - Source Folder # Path - Link Folder
        # PowerShell Module Link
        New-Item -ItemType 'SymbolicLink' -Target "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Modules" -Path "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Modules" -Force | Out-Null
        Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Symbolic Link Created from 'WindowsPowerShell' to 'PowerShell' Modules"

        # PowerShell Profile Link
        New-Item -ItemType 'SymbolicLink' -Target "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" -Path "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.PowerShell_profile.ps1" -Force | Out-Null
        Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Symbolic Link Created from 'WindowsPowerShell' to 'PowerShell' Profile"

        # VSCode Profile Link
        New-Item -ItemType 'SymbolicLink' -Target "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" -Path "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.VSCode_profile.ps1" -Force | Out-Null
        Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Symbolic Link Created from 'WindowsPowerShell' to 'VSCode' Profile"

    }

    if ($host.Version.Major -eq '7') {
        if (Test-Path -Path "$Env:UserProfile\Documents\WindowsPowerShell\Modules" ) {
            Remove-Item -Path "$Env:UserProfile\Documents\WindowsPowerShell\Modules" -Recurse -Force
        }

        # Target - Source Folder # Path - Link Folder

        # PowerShell Module Link
        New-Item -ItemType 'SymbolicLink' -Target "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Modules" -Path "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Modules" -Force | Out-Null
        Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Symbolic Link Created from 'PowerShell' to 'WindowsPowerShell' Modules"

        # PowerShell 5 Profile Link
        New-Item -ItemType 'SymbolicLink' -Target "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.PowerShell_profile.ps1" -Path "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" -Force | Out-Null
        Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Symbolic Link Created from 'PowerShell' to 'WindowsPowerShell' Profile"

        # VSCode Profile Link
        New-Item -ItemType 'SymbolicLink' -Target "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.PowerShell_profile.ps1" -Path "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.VSCode_profile.ps1" -Force | Out-Null
        Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Symbolic Link Created from 'PowerShell' to 'VSCode' Profile"
    }
}

getSystemRequirements

installNerdFont -nerdFontFileName $nerdFontFileName

installPowerShellModules

installWinGetApplications

setPwshProfile

setWindowsTerminal

setCrossPlatformModuleSupport 