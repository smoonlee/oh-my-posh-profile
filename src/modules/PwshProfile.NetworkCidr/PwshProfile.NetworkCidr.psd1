@{
  RootModule = 'PwshProfile.NetworkCidr.psm1'
  ModuleVersion = '1.0.0'
  GUID = '80c37eb7-0dfb-49ba-aa45-e30e2db75c22'
  Author = 'smoonlee'
  Description = 'Optional Pwsh Profile module for standard, Azure, AWS, and GCP IPv4 CIDR calculations.'
  PowerShellVersion = '5.1'
  FunctionsToExport = @('Get-NetworkCidr')
  CmdletsToExport = @()
  VariablesToExport = @()
  AliasesToExport = @()
  FormatsToProcess = @('PwshProfile.NetworkCidr.Format.ps1xml')
  PrivateData = @{
    PSData = @{
      ProjectUri = 'https://github.com/smoonlee/oh-my-posh-profile'
      Tags = @('CIDR', 'IPv4', 'Azure', 'AWS', 'GCP', 'Networking', 'Profile')
    }
  }
}
