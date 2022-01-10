# Script Title
Write-Output '=============================================='
Write-Output '                                              '
Write-Output '      Configure PowerShell Profile Paths      '
#Write-Output '                                              '
Write-Output '=============================================='

If ($host.version -like '5.*') {
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
    Else {
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

If ($host.version -like '7.*') {
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
#Write-Output '                                              '
Write-Output '=============================================='

Import-Module -Name 'PackageManagement'
Import-Module -Name 'PowerShellGet'

Write-Warning -Message 'Installing... Oh-My-Posh'
Install-Module -Repository 'PSGallery' -Name 'Oh-My-Posh' -Force

Write-Warning -Message 'Installing... Posh-Git'
Install-Module -Repository 'PSGallery' -Name 'Posh-Git' -Force

Write-Warning -Message 'Installing... PSReadLine'
Install-Module -Repository 'PSGallery' -Name 'PSReadLine' -AllowPrerelease -Force

# Section Title
Write-Output ''
Write-Output '=============================================='
Write-Output '                                              '
Write-Output '        Configure PowerShell Profile          '
#Write-Output '                                              '
Write-Output '=============================================='

# Configure Profile
"# Import Modules
$("$([Environment]::GetFolderPath("MyDocuments"))\PowerShell\Modules\oh-my-posh\6.44.1\oh-my-posh.psd1" | Import-Module)
$("$([Environment]::GetFolderPath("MyDocuments"))\PowerShell\Modules\posh-git\1.0.0\posh-git.psd1" | Import-Module)
$("$([Environment]::GetFolderPath("MyDocuments"))\PowerShell\Modules\PSReadLine\2.2.0\PSReadLine.psd1" | Import-Module -RequiredVersion 2.2.0)

# Define PSReadLine Configuration
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows

# Configure Oh-My-Posh Prompt
Set-PoshPrompt -Theme paradox

" | Set-Content -Path $ProfilePath
    (Get-Content $ProfilePath).Trim() | Set-Content $ProfilePath

# Verbose - Setup Complete
Write-Output ''
Write-Output 'Windows Terminal - PowerShell Profile Configured!'
. $Profile
exit
