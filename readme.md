![header-image](assets/github-header-imager.png)

# Oh-My-Posh :: Overview :: Mk3

![terminal-preview](assets/windows-terminal-preview.png)

> [!IMPORTANT]
> #Requires -RunAsAdministrator \
> This script requires execution as Administrator, for Nerd Font Installation!

## Release Notes

> **JUNE 2024** \
> Added Get-DnsResult Function \
> Renamed Get-PublicIPAddress to Get-MyPublicIP 
>
> **MAY 2024** \
> Rebuilt Functions for Installation \
> Added custom PowerShell Functions -  Get-PublicIP, Get-SystemUptime, Get-AzSystemUptime, Register-PSProfile, Update-WindowsApps, Remove-GitBranch \
> Added Support for AKS Clusters \
> Added Module Intellisense (Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete)
> Move PowerShell Modules back to User Documents \
> Rebuilt WSL/Linux bash script

## Improvements Over Mk2

Since the release of the Mk2 Profile back in August 2023, I've learnt and realised that the PowerShell modules don't need to be installed directly in the `C:\Program Files\WindowsPowerShell\Modules` folder to get cross platform/version support.
Having completed a lot of testing with some virtual machines, I worked out that you can use: `C:\Users\%UserName%\Documents\PowerShell\Modules` or `C:\Users\%UserName%\Documents\WindowsPowerShell\Modules`\
 By creating symbolic links between the two folder paths, you can import modules across both PowerShell versions.

While doing some research as well around `$PROFILE` tips and tricks, I found some super interesting links:

[Chris Titus Tech - Pretty PowerShell](https://github.com/ChrisTitusTech/powershell-profile) \
[Scott Hanselman - My Ultimate PowerShell Prompt](https://www.hanselman.com/blog/my-ultimate-powershell-prompt-with-oh-my-posh-and-the-windows-terminal) \
[Scott Hanselman - Customizing you Powershell prompt with PSReadLine](https://www.hanselman.com/blog/you-should-be-customizing-your-powershell-prompt-with-psreadline) \
[Anit Jha - Elevate your Windows PowerShell](https://blog.anit.dev/elevate-your-windows-powershell-my-personal-customization-guide)

## Modules, Functions and Applications Overview

### PowerShell Modules

 - [PackageManagement](https://www.powershellgallery.com/packages/PackageManagement)
 - [PowerShellGet](https://www.powershellgallery.com/packages/PowerShellGet)
 - [PSReadLine](https://www.powershellgallery.com/packages/PSReadLine)
 - [Pester](https://www.powershellgallery.com/packages/Pester)
 - [Posh-Git](https://www.powershellgallery.com/packages/posh-git)
 - [Terminal-Icons](https://www.powershellgallery.com/packages/Terminal-Icons)
 - [Az](https://www.powershellgallery.com/packages/Az)

### Winget Modules

 - [JanDeDobbeleer.OhMyPosh](https://winstall.app/apps/JanDeDobbeleer.OhMyPosh)
 - [Git.Git](https://winstall.app/apps/Git.Git)
 - [Github.Cli](https://winstall.app/apps/GitHub.cli)
 - [Microsoft.AzureCLI](https://winstall.app/apps/Microsoft.AzureCLI)
 - [Microsoft.Azure.Kubelogin](https://winstall.app/apps/Microsoft.Azure.Kubelogin)
 - [Kubernetes.kubectl](https://winstall.app/apps/Kubernetes.kubectl)
 - [Helm.Helm](https://winstall.app/apps/Helm.Helm)
 - [Ookla.Speedtest.CLI](https://winstall.app/apps/Ookla.Speedtest.CLI)

### PowerShell Functions

[x] Azure CLI Tab Completion \
<br>
Microsoft Docs Link: [here](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli#enable-tab-completion-in-powershell)

[x]> Get your current Public IP Address

``` powershell
Get-MyPublicIp
```

[x]> Get Local System Uptime

``` powershell
Get-SystemUptime
```

Get-SystemUptime - Example

``` powershell
Hostname: XPS9510-SL
Uptime: 0 days, 4 hours, 6 minutes, 47 seconds
Last Reboot Time: 05/06/2024 10:10:32
```

[x]> Get Uptime of Virtual Machine in Azure

``` powershell
Get-AzSystemUptime -resourceGroup <resourceGroup> -vmName <vmName> -subscriptionId <subscriptionId>
```

Get-AzSystemUptime - Example (Windows)

``` powershell
[Azure] :: Getting System Uptime for windows01 in rg-bwc-sandbox-weu...
WARNING: This may take up to 35 seconds

[Azure] :: Hostname: windows01
[Azure] :: Uptime: 15 days, 4 hours, 25 minutes, 46 seconds
[Azure] :: Last Reboot Time: 06/05/2024 13:19:45
```

Get-AzSystemUptime - Example (Linux)

``` powershell
[Azure] :: Getting System Uptime for vm-learn-linux-weu in rg-learn-linux-weu...
WARNING: This may take up to 35 seconds

[Azure] :: Hostname: vm-learn-linux-weu
[Azure] :: Uptime: up 1 day, 1 hour, 54 minutes
[Azure] :: Last Reboot Time: 2024-05-05 11:27:17
```

[x]> Reload PowerShell Profile

``` powershell
Register-PSProfile
```

Register-PSProfile - Example

``` powershel
WARNING: Powershell Profile Reloaded!
```

[x]> Update Windows Applications (Using WinGet)

``` powershell
Update-WindowsApps
```

Update-WindowsApps - Examples

``` powershell
Updating Windows Applications...

Name            Id                 Version Available Source
-----------------------------------------------------------
Hugo (Extended) Hugo.Hugo.Extended 0.125.5 0.125.6   winget
1 upgrades available.
```

[x]> Remove-GitBranch (Singe Branch)

``` powershell
Remove-GitBranch -branchName <branchname>
```

Remove-GitBranch -branchName - Example

``` powershell
Deleted branch branch1 (was b7ef979).
```

[x]> Remove-GitBranch (All Branches)
> This excludes 'main' and 'master' branches

``` powershell
Remove-GitBranch -all
```

Remove-GitBranch -all - Example

``` powershell
WARNING: This will remove all local branches in the repository!
Press any key to continue...

[Git] :: Moving to main branch
Switched to branch 'main'
Your branch and 'origin/main' have diverged,
and have 8 and 1 different commits each, respectively.
  (use "git pull" if you want to integrate the remote branch with yours)

[Git] :: Starting Branch Cleanse
Deleted branch branch1 (was b7ef979).
Deleted branch branch2 (was b7ef979).
Deleted branch branch3 (was b7ef979).
Deleted branch branch4 (was b7ef979).
Deleted branch branch5 (was b7ef979).
```

[x] Get-DnsReuslt
> Query DNS direct from the shell 👌

``` powershell
Get-DnsResult -domain builtwithcaffeine.cloud -recordType NS
```

Get-DnsResults - Example
``` powershell
Name                           Type   TTL   Section    NameHost
----                           ----   ---   -------    --------
builtwithcaffeine.cloud        NS     86400 Answer     ns1-02.azure-dns.com
builtwithcaffeine.cloud        NS     86400 Answer     ns2-02.azure-dns.net
builtwithcaffeine.cloud        NS     86400 Answer     ns3-02.azure-dns.org
builtwithcaffeine.cloud        NS     86400 Answer     ns4-02.azure-dns.info
```

Supported RecordTypes:
>
> A           ALL         DNAME       ISDN        MG          NS          NULL        RRSIG       X25 \
> A_AAAA      ANY         DNSKEY      MB          MINFO       NSEC        OPT         RT          TXT \
> AAAA        CNAME       DS          MD          MR          NSEC3       PTR         SOA         WINS \
> AFSDB       DHCID       HINFO       MF          MX          NSEC3PARAM  RP          SRV         WKS
>

## Windows Terminal Nerd Font

Nerd Fonts patches developer targeted fonts with a high number of glyphs (icons). Specifically to add a high number of extra glyphs from popular 'iconic fonts'
You can get yours here: [Nerd Font](https://www.nerdfonts.com/font-downloads)

Using the `New-OhMyPoshProfile.ps1` it will auto install the `Cascadia Code` Font. \
The font file which is installed is the: `CaskaydiaCoveNerdFont-Regular.ttf` \
If you want to add this support to Visual Studio Code, you can update the Font Family:

``` powershell
'Consolas', 'Courier New', 'CaskaydiaCove Nerd Font'
```

## Pre Device Setup

> [!IMPORTANT]
> If you've used the v2 setup, You'll manually need to remove Modules from \
> pwsh7 :: C:\Program Files\PowerShell\Modules \
> pwsh5 :: C:\Program Files\WindowsPowerShell\Modules

### PowerShell 5 default modules

``` powershell
Directory: C:\Program Files\WindowsPowerShell\Modules

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d-----        07/05/2022     06:42                Microsoft.PowerShell.Operation.Validation
d-----        07/05/2022     06:42                PackageManagement
d-----        07/05/2022     06:42                Pester
d-----        07/05/2022     06:42                PowerShellGet
d-----        07/05/2022     06:42                PSReadLine
```

## Profile Setup

### -> Windows

<details>
<summary> New Device Setup </summary>
<br>
Ensure that you can execute scripts on your local machine
<br>

``` powershell
Set-ExecutionPolicy -Scope 'CurrentUser' -ExecutionPolicy 'RemoteSigned'
```

Download and execute the New-PSProfile.ps1 script.

``` powershell
$setupUrl = 'https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile/main/New-OhMyPoshProfile.ps1'
Invoke-WebRequest -Uri $setupUrl -OutFile $Pwd\New-OhMyPoshProfile.ps1
.\New-OhMyPoshProfile.ps1
```

</details>

### -> Linux

<details>
<summary> New Device Setup </summary>
<br>

``` bash
setupUrl='https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile/main/New-OhMyPoshProfile.sh'
curl -s $setupUrl -o $HOME/New-OhMyPoshProfile.sh ; bash New-OhMyPoshProfile.sh
```

</details>

<details>
<summary> WSL :: Kubernetes </summary>
<br>

> **NOTE** \
> Since Mk3, This is built into the setup script!

You might need to create the `.kube` folder first.

``` bash
mkdir $HOME/.kube
```

Then create a symbolic link to the Windows `.kube` folder.

> **NOTE** \
> Please update the Users folder to match your Windows User folder

``` bash
ln -sf /mnt/c/Users/<username>/.kube/config $HOME/.kube/config
```
</details>
