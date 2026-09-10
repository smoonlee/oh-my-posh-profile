@{
  RootModule = 'PwshProfile.PublicIP.psm1'
  ModuleVersion = '1.0.0'
  GUID = '3b6fb7ba-a814-482f-b947-ff973970bdcb'
  Author = 'smoonlee'
  Description = 'Optional Pwsh Profile function for retrieving public IP, ISP, and location information.'
  PowerShellVersion = '5.1'
  FunctionsToExport = @('Get-PublicIP')
  CmdletsToExport = @()
  VariablesToExport = @()
  AliasesToExport = @()
  PrivateData = @{
    PSData = @{
      ProjectUri = 'https://github.com/smoonlee/oh-my-posh-profile'
      Tags = @('PublicIP', 'Profile')
    }
  }
}
