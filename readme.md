# Windows Terminal and Visual Studio Code : Profile Script


#### Prerequisites for powershell_profile 
 Install the Microsoft Windows Terminal Application
```
 winget.exe install --silent --exact --id Microsoft.WindowsTerminal
```

 Install the Microsoft Visual Studio Code Application
 ```
 winget.exe install --silent --exact --id Microsoft.VisualStudioCode --scope machine
 ```

 Install the PowerShell 7.0
 ```
 winget.exe install --silent --exact --id Microsoft.PowerShell
```

#### VSCode : Editor: Font Family 
```
Consolas, 'Courier New', 'CaskaydiaCove Nerd Font'
```

## powershell_profile Setup

Download the Github repository

```
git clone https://github.com/smoonlee/powershell_profile.git
```

Execute
```
.\New-PsProfile.ps1 
```

Close Windows Terminal, and Edit VSCode Font Family 🥳

