@{
  RootModule = 'PwshProfile.Dns.psm1'
  ModuleVersion = '1.0.1'
  GUID = '3d9f7c2e-6b1a-4f8e-9c2d-5a7e1b6c4f90'
  Author = 'smoonlee'
  Description = 'Optional Pwsh Profile module for querying DNS records.'
  PowerShellVersion = '5.1'
  FunctionsToExport = @('Get-DnsResult')
  CmdletsToExport = @()
  VariablesToExport = @()
  AliasesToExport = @()
  FormatsToProcess = @('PwshProfile.Dns.Format.ps1xml')
  PrivateData = @{
    PSData = @{
      ProjectUri = 'https://github.com/smoonlee/oh-my-posh-profile'
      Tags = @('DNS', 'Networking', 'Profile')
    }
  }
}
