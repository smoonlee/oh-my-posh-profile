If ($host.version -like '5.*') {
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
}
