<#
.NAME 
    PowerShell Profile Configuration Script

.AUTHOR
    Simon Lee
    @smoon_lee

.CHANGELOG
    2022-01-10 - Inital Script Created - version: 1.0
    2022.01.11 - Script Debugged - version: 1.0
    2022.01.11 - Added extra SymbolicLink Clean up Logic - version: 1.1
    2022.01.11 - Rewrote Module Install Section, With better Logic - version: 1.1.1
    2022.01.11 - BugFixes - PSReadLine - version 1.1.2
#>

# Script Title
if ((Get-Item -Path "$([Environment]::GetFolderPath("MyDocuments"))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" -ErrorAction SilentlyContinue) -or (Get-Item -Path "$([Environment]::GetFolderPath("MyDocuments"))\PowerShell\Microsoft.PowerShell_profile" -ErrorAction  SilentlyContinue)) {
    Write-Output '=============================================='
    Write-Output '                                              '
    Write-Output '      Pre Configure - Profile Cleanup      '
    Write-Output '=============================================='
    
    Remove-Item -Path "$([Environment]::GetFolderPath("MyDocuments"))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
    Remove-Item -Path "$([Environment]::GetFolderPath("MyDocuments"))\PowerShell\Microsoft.PowerShell_profile.ps1"
    Remove-Item -Path "$([Environment]::GetFolderPath("MyDocuments"))\PowerShell\Microsoft.VSCode_profile.ps1"
    Write-Warning -Message 'Microsoft.PowerShell_profile Removed!'
}

Write-Output '=============================================='
Write-Output '                                              '
Write-Output '      Configure PowerShell Profile Paths      '
Write-Output '=============================================='

if ($host.version -like '5.*') {
    Write-Warning 'PowerShell 5 Detected'
    if ((Get-Module -ListAvailable PowerShellGet).version -Join "*.*" -eq '1.0.0.1') {
        Write-Warning -Message 'PackageManagement and PowerShelGet Out-Of-Date!'
        Write-Warning -Message 'Installing... NuGet'	
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null    

        Write-Warning -Message 'Configuring PSGallery Installation Policy'
        Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted'

        Write-Warning -Message 'Installing... PackageManagement'
        Install-Module -Repository 'PSGallery' -Name 'PackageManagement' -Force | Out-Null
        Start-Sleep -Seconds 2
        
        Write-Warning -Message 'Installing... PowerShellGet'
        Install-Module -Repository 'PSGallery' -Name 'PowerShellGet' -Force | Out-Null

        Write-Warning -Message 'Please Close Windows Terminal and Re Lauch script'
        exit 1
    }
    else {
        Write-Warning -Message 'PackageManagement and PowerShelGet Up-To-Date!'
	
    }

    # Create Default Profile
    $ProfilePath = "$([Environment]::GetFolderPath("MyDocuments"))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
    New-Item -ItemType 'File' -Path $ProfilePath -Force | Out-Null
    Write-Warning -Message 'Default Profile Path Created'

    # Create Synbolic Links 
    New-Item -ItemType SymbolicLink -Target $ProfilePath -Path "$([Environment]::GetFolderPath("MyDocuments"))\PowerShell\Microsoft.PowerShell_profile.ps1" -Force | Out-Null
    New-Item -ItemType SymbolicLink -Target $ProfilePath -Path "$([Environment]::GetFolderPath("MyDocuments"))\PowerShell\Microsoft.VSCode_profile.ps1" -Force | Out-Null
    Write-Warning -Message 'Symbolic Link Created for PowerShell 7.x and Visual Studio Code'
}

if ($host.version -like '7.*') {
    Write-Warning 'PowerShell 7 Detected'
    # Create Default Profile
    $ProfilePath = "$([Environment]::GetFolderPath("MyDocuments"))\PowerShell\Microsoft.PowerShell_profile.ps1"
    New-Item -ItemType 'File' -Path $ProfilePath -Force | Out-Null
    Write-Warning -Message 'Default Profile Path Created'

    # Create Synbolic Links 
    New-Item -ItemType SymbolicLink -Target $ProfilePath -Path "$([Environment]::GetFolderPath("MyDocuments"))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" -Force | Out-Null
    New-Item -ItemType SymbolicLink -Target $ProfilePath -Path "$([Environment]::GetFolderPath("MyDocuments"))\PowerShell\Microsoft.VSCode_profile.ps1" -Force | Out-Null
    Write-Warning -Message 'Symbolic Link Created for PowerShell 5.1 and Visual Studio Code'
} 

# Section Title
Write-Output ''
Write-Output '=============================================='
Write-Output '                                              '
Write-Output '        Installing PowerShell Modules         '
Write-Output '=============================================='

if ($host.version -like '5.*') {
    if (!(Test-Path -Path 'C:\Program Files\WindowsPowerShell\Modules\Oh-My-Posh')) {
        # Install PowerShell Module - Oh-My-Posh
        Write-Warning -Message 'Installing... Oh-My-Posh'
        Install-Module -Repository 'PSGallery' -Scope 'AllUsers' -Name 'Oh-My-Posh' -Force

        # Provision Symlboic Link
        if (Test-Path -Path 'C:\Program Files\PowerShell\Modules\Oh-My-Posh') {
            if ((Get-Item -Path 'C:\Program Files\PowerShell\Modules\Oh-My-Posh').LinkType -like 'SymbolicLink') {
                (Get-Item -Path 'C:\Program Files\PowerShell\Modules\Oh-My-Posh').Delete()
            }
            Else {
                Remove-Item -Path 'C:\Program Files\PowerShell\Modules\Oh-My-Posh' -Force -Recurse
            }
            New-Item -ItemType SymbolicLink -Path 'C:\Program Files\PowerShell\Modules\Oh-My-Posh' -Target 'C:\Program Files\WindowsPowerShell\Modules\Oh-My-Posh'  -Force | Out-Null
            Write-Warning -Message 'Oh-My-Posh Symbolic Link Created.'
            Write-Output ''
        }
        else {
            New-Item -ItemType SymbolicLink -Path 'C:\Program Files\PowerShell\Modules\Oh-My-Posh' -Target 'C:\Program Files\WindowsPowerShell\Modules\Oh-My-Posh'  -Force | Out-Null
            Write-Warning -Message 'Oh-My-Posh Symbolic Link Created.'
            Write-Output ''
        }
    }
    else {
        Write-Warning -Message 'Oh-My-Posh already installed.'
        Write-Output ''
    }

    if (!(Test-Path -Path 'C:\Program Files\WindowsPowerShell\Modules\Posh-Git')) {
        # Install PowerShell Module - Posh-Git
        Write-Warning -Message 'Installing... Posh-Git'
        Install-Module -Repository 'PSGallery' -Scope 'AllUsers' -Name 'Posh-Git' -Force

        # Provision Symlboic Link
        if (Test-Path -Path 'C:\Program Files\PowerShell\Modules\Posh-Git') {
            if ((Get-Item -Path 'C:\Program Files\PowerShell\Modules\Posh-Git').LinkType -like 'SymbolicLink') {
                (Get-Item -Path 'C:\Program Files\PowerShell\Modules\Posh-Git').Delete()
            }
            Else {
                Remove-Item -Path 'C:\Program Files\PowerShell\Modules\Posh-Git' -Force -Recurse
            }
            New-Item -ItemType SymbolicLink -Path 'C:\Program Files\PowerShell\Modules\Posh-Git' -Target 'C:\Program Files\WindowsPowerShell\Modules\Posh-Git'  -Force | Out-Null
            Write-Warning -Message 'Posh-Git Symbolic Link Created.'
            Write-Output ''
        }
        else {
            New-Item -ItemType SymbolicLink -Path 'C:\Program Files\PowerShell\Modules\Posh-Git' -Target 'C:\Program Files\WindowsPowerShell\Modules\Posh-Git'  -Force | Out-Null
            Write-Warning -Message 'Posh-Git Symbolic Link Created.'
            Write-Output ''
        }
    }
    else {
        Write-Warning -Message 'Posh-Git already installed.'
        Write-Output ''
    }
   
    if (!(Test-Path -Path 'C:\Program Files\WindowsPowerShell\Modules\PSReadLine\2.2.0')) {
        # Install PowerShell Module - PSReadLine
        Write-Warning -Message 'Installing... PSReadLine'
        Install-Module -Repository 'PSGallery' -Scope 'AllUsers' -Name 'PSReadLine' -AllowPrerelease -Force

        # Provision Symlboic Link
        if (Test-Path -Path 'C:\Program Files\PowerShell\Modules\PSReadLine') {
            if ((Get-Item -Path 'C:\Program Files\PowerShell\Modules\PSReadLine').LinkType -like 'SymbolicLink') {
                (Get-Item -Path 'C:\Program Files\PowerShell\Modules\PSReadLine').Delete()
            }
            Else {
                Remove-Item -Path 'C:\Program Files\PowerShell\Modules\PSReadLine' -Force -Recurse
            }
            New-Item -ItemType SymbolicLink -Path 'C:\Program Files\PowerShell\Modules\PSReadLine' -Target 'C:\Program Files\WindowsPowerShell\Modules\PSReadLine'  -Force | Out-Null
            Write-Warning -Message 'PSReadLine Symbolic Link Created.'
            Write-Output ''
        }
        else {
            New-Item -ItemType SymbolicLink -Path 'C:\Program Files\PowerShell\Modules\PSReadLine' -Target 'C:\Program Files\WindowsPowerShell\Modules\PSReadLine'  -Force | Out-Null
            Write-Warning -Message 'PSReadLine Symbolic Link Created.'
            Write-Output ''
        }
    }
    else {
        Write-Warning -Message 'PSReadLine already installed.'
    }
}

if ($host.version -like '7.*') {
    if (!(Test-Path -Path 'C:\Program Files\PowerShell\Modules\Oh-My-Posh')) {
        # Install PowerShell Module - Oh-My-Posh
        Write-Warning -Message 'Installing... Oh-My-Posh'
        Install-Module -Repository 'PSGallery' -Scope 'AllUsers' -Name 'Oh-My-Posh' -Force

        # Provision Symlboic Link
        if (Test-Path -Path 'C:\Program Files\WindowsPowerShell\Modules\Oh-My-Posh') {
            if ((Get-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Oh-My-Posh').LinkType -like 'SymbolicLink') {
                (Get-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Oh-My-Posh').Delete()
            }
            Else {
                Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Oh-My-Posh' -Force -Recurse
            }
            New-Item -ItemType SymbolicLink -Path 'C:\Program Files\WindowsPowerShell\Modules\Oh-My-Posh' -Target 'C:\Program Files\PowerShell\Modules\Oh-My-Posh'  -Force | Out-Null
            Write-Warning -Message 'Oh-My-Posh Symbolic Link Created.'
            Write-Output ''
        }
        else {
            New-Item -ItemType SymbolicLink -Path 'C:\Program Files\WindowsPowerShell\Modules\Oh-My-Posh' -Target 'C:\Program Files\PowerShell\Modules\Oh-My-Posh'  -Force | Out-Null
            Write-Warning -Message 'Oh-My-Posh Symbolic Link Created.'
            Write-Output ''
        }
    }
    else {
        Write-Warning -Message 'Oh-My-Posh already installed.'
        Write-Output ''
    }

    if (!(Test-Path -Path 'C:\Program Files\PowerShell\Modules\Posh-Git')) {
        # Install PowerShell Module - Posh-Git
        Write-Warning -Message 'Installing... Posh-Git'
        Install-Module -Repository 'PSGallery' -Scope 'AllUsers' -Name 'Posh-Git' -Force

        # Provision Symlboic Link
        if (Test-Path -Path 'C:\Program Files\WindowsPowerShell\Modules\Posh-Git') {
            if ((Get-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Posh-Git').LinkType -like 'SymbolicLink') {
                (Get-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Posh-Git').Delete()
            }
            Else {
                Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Posh-Git' -Force -Recurse
            }
            New-Item -ItemType SymbolicLink -Path 'C:\Program Files\WindowsPowerShell\Modules\Posh-Git' -Target 'C:\Program Files\PowerShell\Modules\Posh-Git'  -Force | Out-Null
            Write-Warning -Message 'Posh-Git Symbolic Link Created.'
            Write-Output ''
        }
        else {
            New-Item -ItemType SymbolicLink -Path 'C:\Program Files\WindowsPowerShell\Modules\Posh-Git' -Target 'C:\Program Files\PowerShell\Modules\Posh-Git'  -Force | Out-Null
            Write-Warning -Message 'Posh-Git Symbolic Link Created.'
            Write-Output ''
        }
    }
    else {
        Write-Warning -Message 'Posh-Git already installed.'
        Write-Output ''
    }    

    if (!(Test-Path -Path 'C:\Program Files\PowerShell\Modules\PSReadLine\2.2.0')) {
        # Install PowerShell Module - PSReadLine
        Write-Warning -Message 'Installing... PSReadLine'
        Install-Module -Repository 'PSGallery' -Scope 'AllUsers' -Name 'PSReadLine' -AllowPrerelease  -Force
    
        # Provision Symlboic Link
        if (Test-Path -Path 'C:\Program Files\WindowsPowerShell\Modules\PSReadLine\2.2.0') {
            if ((Get-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\PSReadLine\2.2.0').LinkType -like 'SymbolicLink') {
                (Get-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\PSReadLine\2.2.0').Delete()
            }
            Else {
                Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\PSReadLine\2.2.0' -Force -Recurse
            }
            New-Item -ItemType SymbolicLink -Path 'C:\Program Files\WindowsPowerShell\Modules\PSReadLine\2.2.0' -Target 'C:\Program Files\PowerShell\Modules\PSReadLine\2.2.0'  -Force | Out-Null
            Write-Warning -Message 'PSReadLine Symbolic Link Created.'
            Write-Output ''
        }
        else {
            New-Item -ItemType SymbolicLink -Path 'C:\Program Files\WindowsPowerShell\Modules\PSReadLine\2.2.0' -Target 'C:\Program Files\PowerShell\Modules\PSReadLine\2.2.0'  -Force | Out-Null
            Write-Warning -Message 'PSReadLine Symbolic Link Created.'
            Write-Output ''
        }
    }
    else {
        Write-Warning -Message 'PSReadLine already installed.'
    }    
}

# Section Title
Write-Output ''
Write-Output '=============================================='
Write-Output '                                              '
Write-Output '        Configure PowerShell Profile          '
#Write-Output '                                              '
Write-Output '=============================================='

# Configure Profile
"# Import Modules
#Import-Module -Name 'PSReadLine'
if ((Get-Variable Host).Value.Version -like '5.*') { 
'C:\Program Files\WindowsPowerShell\Modules\PSReadLine\2.2.0\PSReadLine.psd1' | Import-Module
} 
Import-Module -Name 'Oh-My-Posh'
Import-Module -Name 'Posh-Git'

# Define PSReadLine Configuration
Set-PSReadLineOption -PredictionSource History | Out-Null
Set-PSReadLineOption -PredictionViewStyle ListView | Out-Null
Set-PSReadLineOption -EditMode Windows

# Configure Oh-My-Posh Prompt
Set-PoshPrompt -Theme paradox
" | Set-Content -Path $ProfilePath
    (Get-Content $ProfilePath).Trim() | Set-Content $ProfilePath

# Verbose - Setup Complete
Write-Output ''
Write-Output 'Windows Terminal - PowerShell Profile Configured!'
