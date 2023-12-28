![github-header-image](content/github-header-imager.png)

## Oh-My-Posh :: Overview
This repository contains my PowerShell Profile and the scripts to install the profile for Windows and Linux.

![windows-terminal-exmaple](content/windows-terminal-example.png)

### Pre-requisite checks - winget modules
 - [Microsoft.WindowsTerminal](https://winstall.app/apps/Microsoft.WindowsTerminal)
 - [Microsoft.PowerShell](https://winstall.app/apps/Microsoft.PowerShell) *
 - [Microsoft.VisualStudioCode](https://winstall.app/apps/Microsoft.VisualStudioCode) \
'*' If installed from winget it installs under `"C:\Program Files\PowerShell\7\pwsh.exe"`

### PowerShell Modules
 - [PackageManagement](https://www.powershellgallery.com/packages/PackageManagement) [PowerShell 5.0] 
 - [PowerShellGet](https://www.powershellgallery.com/packages/PowerShellGet) [PowerShell 5.0]
 - [PSReadLine](https://www.powershellgallery.com/packages/PSReadLine) [PowerShell 5.0]
 - [Pester](https://www.powershellgallery.com/packages/Pester) [PowerShell 5.0] [PowerShell 7.0]
 - [Posh-Git](https://www.powershellgallery.com/packages/posh-git) [PowerShell 5.0] [PowerShell 7.0]
 - [Terminal-Icons](https://www.powershellgallery.com/packages/Terminal-Icons) [PowerShell 5.0] [PowerShell 7.0]
 - [Az](https://www.powershellgallery.com/packages/Az) [PowerShell 5.0] [PowerShell 7.0]

During the installation of the PowerShell Modules they are installed to the `"%PROGRAMFILES%\WindowsPowerShell\Modules"` \
this allows for cross-version module import from PowerShell 5.1 and PowerShell 7.0

### Winget Modules
 - [JanDeDobbeleer.OhMyPosh](https://winstall.app/apps/JanDeDobbeleer.OhMyPosh)
 - [Git.Git](https://winstall.app/apps/Git.Git)
 - [Github.Cli](https://winstall.app/apps/GitHub.cli)
 - [Microsoft.AzureCLI](https://winstall.app/apps/Microsoft.AzureCLI)
 - [Microsoft.Azure.Kubelogin](https://winstall.app/apps/Microsoft.Azure.Kubelogin)
 - [Kubernetes.kubectl](https://winstall.app/apps/Kubernetes.kubectl)
 - [Helm.Helm](https://winstall.app/apps/Helm.Helm)

## Oh-My-Posh :: Windows

<details>
<summary> New Device Setup </summary>
 
> NEW DEVICE SETUP \
Please open Powershell 5.1 as Administrator and run the following commands

Check PowerShell Execution Policy - If Execution Policy is `Default` update to `RemoteSigned`
``` powershell
Get-ExecutionPolicy
```

Update Execution Policy
``` powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned 
```
Accept the Execution Policy Change: [A] Yes to all

``` powershell
Execution Policy Change
The execution policy helps protect you from scripts that you do not trust. Changing the execution policy might expose
you to the security risks described in the about_Execution_Policies help topic at
https:/go.microsoft.com/fwlink/?LinkID=135170. Do you want to change the execution policy?
[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "N"):

```

Download PsProfile Script 
``` powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile/main/New-PsProfile.ps1" -OutFile "$PWD\New-PsProfile.ps1" 
```
Execute Script
``` powershell
.\New-PsProfile.ps1
```
</details>

<details>
<summary> Reset Profile </summary>

Download PsProfile Script 
``` powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile/main/New-PsProfile.ps1" -OutFile "$PWD\New-PsProfile.ps1" 
```
Execute Script
``` powershell
.\New-PsProfile.ps1 -ResetProfile
```

</details>


## Oh-My-Posh :: Linux

<details>
<summary> New Device Setup </summary>

``` bash
curl -s https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile/main/New-BashProfile.sh -o $HOME/New-BashProfile.sh
```

Execute Script
``` bash
bash New-BashProfile.sh
```
</details>

<details>
<summary> WSL :: Kubernetes </summary>

You might need to create the `.kube` folder first
```
mkdir $HOME/.kube
```

Then create a symbolic link to the Windows `.kube` folder
> NOTE: Please update the Users folder to match your Windows User folder
```
ln -sf /mnt/c/Users/<username>/.kube/config $HOME/.kube/config
```
</details>

## Oh-My-Posh :: VSCode Nerd Font Installation
Obviously using Oh-My-Posh required a [Nerd Font](https://www.nerdfonts.com/font-downloads) of choice. \
For this setup script, my chosen font is: [CaskaydiaCove Nerd Font](https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/CascadiaCode.zip) \
Specially this ttf font style: `*CaskaydiaCoveNerdFont-Regular.ttf*`

For the VSCode Font Family settings, you will want to use: \

`File > Preferences > Settings` Search for `Font Family` > Edit in settings.json
```
Consolas, 'Courier New', 'CaskaydiaCove Nerd Font'
```
