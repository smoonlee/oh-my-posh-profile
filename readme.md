![github-header-image](content/github-header-imager.png)

## Oh-My-Posh :: Windows

### New Device Setup 
Check PowerShell Execution Policy - If Execution Policy is `Default` update to `RemoteSigned`
``` powershell
Get-ExecutionPolicy
```

Update Execution Policy
``` powershell
Set-ExecutionPolicy -Scope CurrentUser-ExecutionPolicy RemoteSigned 
```

Download PsProfile Script 
``` powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile/main/New-PsProfile.ps1" -OutFile "$([Environment]::GetFolderPath("Desktop"))\New-PsProfile.ps1" 
```
Execute Script
``` powershell
.\New-PsProfile.ps1
```

### Reset Profile 

Download PsProfile Script 
``` powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile/main/New-PsProfile.ps1" -OutFile "$([Environment]::GetFolderPath("Desktop"))\New-PsProfile.ps1" 
```
Execute Script
``` powershell
.\New-PsProfile.ps1 -ResetProfile
```

## Oh-My-Posh :: Linux