@{
  RootModule = 'PwshProfile.EndOfLife.psm1'
  ModuleVersion = '1.0.2'
  GUID = '6a1b96ff-38db-47c5-b15a-03775ca258cb'
  Author = 'smoonlee'
  Description = 'Optional Pwsh Profile module for querying lifecycle support and end-of-life dates from endoflife.date.'
  PowerShellVersion = '5.1'
  FunctionsToExport = @('Get-EolInfo')
  CmdletsToExport = @()
  VariablesToExport = @()
  AliasesToExport = @()
  FormatsToProcess = @('PwshProfile.EndOfLife.Format.ps1xml')
  PrivateData = @{
    PSData = @{
      ProjectUri = 'https://github.com/smoonlee/oh-my-posh-profile'
      Tags = @('EndOfLife', 'Lifecycle', 'Support', 'Profile')
    }
  }
}
