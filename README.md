# PowerShell_profile

# Configure PowerShell Execution Policy First!
`Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`

# PowerShell 5.1.x Profile Path 
### Default 
'C:\Users\\$Env:USERNAME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'

### PowerShell Path
`"$([Environment]::GetFolderPath("MyDocuments"))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"`

# PowerShell 7.x 
### Default 
'C:\Users\\$Env:USERNAME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1'`

### PowerShell Path
`"$([Environment]::GetFolderPath("MyDocuments"))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"`

# Visual Studio Code
### Default 
'C:\Users\\$Env:USERNAME\Documents\Documents\PowerShell\Microsoft.VSCode_profile.ps1'

### PowerShell Path
`"$([Environment]::GetFolderPath("MyDocuments"))\PowerShell\Microsoft.VSCode_profile.ps1"`
