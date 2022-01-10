# Guide - https://randomnote1.github.io/powershell/manually-install-module-from-the-powershell-gallery/#:~:text=Install%20the%20module%201%20Rename%20the%20module%20replacing,to%20install%20the%20module.%20...%20More%20items...%20

# Download NuPkg Package
$TempPath = 'C:\Windows\Temp'
Invoke-WebRequest -Uri 'https://psg-prod-eastus.azureedge.net/packages/psreadline.2.2.0-beta2.nupkg' -OutFile "$TempPath\psreadline.2.2.0-beta2.nupkg"

# Extract NuGet Pkg
Move-Item -Path "$TempPath\psreadline.2.2.0-beta2.nupkg" -Destination "$TempPath\psreadline.2.2.0-beta2.zip" -Force | Out-Null
Expand-Archive -Path "$TempPath\psreadline.2.2.0-beta2.zip" -DestinationPath "$TempPath\2.2.0" -Force | Out-Null
Remove-Item -Path "$TempPath\psreadline.2.2.0-beta2.zip"
New-Item -ItemType 'Directory' -Path $env:ProgramFiles\WindowsPowerShell\Modules\PSReadLine -Force | Out-Null
Move-Item -Path "$TempPath\2.2.0" -Destination 'C:\Program Files\WindowsPowerShell\Modules\PSReadLine\2.2.0' -Force 

