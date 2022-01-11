#
![psprofile_header_Image](content/psprofile_header_image.png "PSProfile Automated Installation Script")
#
  
### Configure PowerShell Execution Policy.
If running script on a fresh installation of Windows, This MUST be run on PowerShell 5 and PowerShell 7.x

```
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

### Module Version Support | Get-PowerShellGet.ps1
Must have PowerShellGet Module above 1.6.0 - Otherwisew PowerShell 5.1 configuration fails to run.
Download the below file to check PowerShellGet and PackageManagement are Up-To-Date.

```
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/smoonlee/powershell_profile/main/Check-PowerShellGet.ps1' -OutFile "$([Environment]::GetFolderPath("Desktop"))\Check-PowerShellGet.ps1"
```

#### Execute Get-PowerShellGet.ps1 Script
```
& "$([Environment]::GetFolderPath("Desktop"))\Check-PowerShellGet.ps1"
```

![gif_animation](/content/graphic_check-powershellget.gif)

### Reset PSProfile Environment | Reset-PSProfile.ps1
If you have issues with your PSProfile configuation, You can download and execute this script. It will remove the following modules.
<p>'Oh-My-Posh, Posh-Git, PSReadLines (2.2.0)'</p>

```
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/smoonlee/powershell_profile/main/Reset-PSProfileEnv.ps1' -OutFile "$([Environment]::GetFolderPath("Desktop"))\Reset-PSProfileEnv.ps1"
```

#### Execute Get-PowerShellGet.ps1 Script
```
& "$([Environment]::GetFolderPath("Desktop"))\Reset-PSProfileEnv.ps1"
```

![gif_animation](/content/graphic_reset-psprofileenv.gif)

### Install-PSProfile.ps1

#### PSProfile Script without NerdFont Assisted Installation (Requires manual Font installation from: [NerdFonts](https://www.nerdfonts.com/).

```
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/smoonlee/powershell_profile/main/Install-PSProfile_NoNerdFonts.ps1' -OutFile "$([Environment]::GetFolderPath("Desktop"))\Install-PSProfile_NoNerdFonts.ps1"
```

#### Execute Get-PowerShellGet.ps1 Script
```
& "$([Environment]::GetFolderPath("Desktop"))\Install-PSProfile_NoNerdFonts.ps1"
```

![gif_animation](/content/graphic_install-psprofile_pwsh7.gif)

#### PSProfile Script with NerdFont Assisted Installation
``` 
Coming Soon 
```

##  Current Windows Termianal Configuration
![WindowsTermianl-PowerShell7](content/windows_terminal_powershell_7.png "WindowsTermianl-PowerShell7")

#### Current Shells
 * Azure Cloud Shell  
 * PowerShell 7.* (Microsoft Store)
 * PowerShell 5.1
 * Command Prompt
 * Ubuntu (WSL)

#### Terminal Appearance 
-  Text : Colour Scheme : One Half Dark
-  Text : Font Face : [Agave (Nerd Font)](https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/Agave.zip)
-  Text : Font Size : 10px
-  Text : Font Weight : Normal
-  Cursor Shape : Bar
-  Text : Formatting : Bright Colours
- Window : Padding : 8px
- Scrollbar : Visible
 
 
##  PowerShell Profile Path Locations
### PowerShell 5.1.x Profile Path 
#### Default 
```
'C:\Users\\$Env:USERNAME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
 ```

#### PowerShell Path
```
"$([Environment]::GetFolderPath("MyDocuments"))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
```

###  PowerShell 7.x 
#### Default 
```
'C:\Users\\$Env:USERNAME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
```

### PowerShell Path
```
"$([Environment]::GetFolderPath("MyDocuments"))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
```

### Visual Studio Code
#### Default 
```
C:\Users\\$Env:USERNAME\Documents\Documents\PowerShell\Microsoft.VSCode_profile.ps1
```

#### PowerShell Path
```
"$([Environment]::GetFolderPath("MyDocuments"))\PowerShell\Microsoft.VSCode_profile.ps1"
```
