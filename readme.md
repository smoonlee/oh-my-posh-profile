![psprofile-automated-installation-script-header-png](content/github_psprofile_v2_header.png)

# Welcome to the PSProfile Generation Two Point Zero Setup Repository

### Pre-requites Applications required: 
> Microsoft.WindowsTerminal \
> Microsoft.PowerShell \
> Microsoft.VisualStudioCode 
> 
<details>
<summary>Manual Installation of Packages</summary>

#### Microsoft.WindowsTerminal 
```
winget.exe install --exact --silent --id Microsoft.WindowsTerminal
```

#### Microsoft.PowerShell
```
winget.exe install --exact --silent --id Microsoft.PowerShell
```

#### Microsoft.VisualStudioCode
```
winget.exe install --exact --silent --id Microsoft.VisualStudioCode --scope machine
```
</details>

## New Computer Setup (Fresh OS Deployment)
#### Download zip file and extract 
```
Invoke-WebRequest -Uri "https://github.com/smoonlee/powershell_profile/archive/refs/heads/main.zip" -Outfile $([Environment]::GetFolderPath("Desktop"))\psprofile.zip
```

#### Extract Zip file
```
Expand-Archive -Path "$([Environment]::GetFolderPath("Desktop"))\psprofile.zip" -DestinationPath "$([Environment]::GetFolderPath("Desktop"))\psprofile"
```

```
Set-Location -Path "$([Environment]::GetFolderPath("Desktop"))\psprofile\powershell_profile-main"
```

#### Execute New-PsProfile Script
```
.\New-PsProfile.ps1
```

## PsProfile Reset 

#### Clone Github Repository
```
git clone https://github.com/smoonlee/powershell_profile.git
```

#### Enter Github Repository Folder
```
Set-Location -Path <path-to-git-clone-folder>
```

#### Execute PsProfile
```
New-PsProfile.ps1 -ResetProfile
```

### Windows Terminal Preview 

![windows-termianl-psprfile-example](content/windows-terminal-psprpfile-pwsh7.png)