@{
  RootModule = 'PwshProfile.AzureKubernetes.psm1'
  ModuleVersion = '1.0.0'
  GUID = 'f3a1c254-2107-4fe4-a1c1-0f7146f0cace'
  Author = 'smoonlee'
  Description = 'Optional Pwsh Profile module for listing Azure Kubernetes Service Kubernetes versions available in a region.'
  PowerShellVersion = '5.1'
  FunctionsToExport = @('Get-AksVersion')
  CmdletsToExport = @()
  VariablesToExport = @()
  AliasesToExport = @()
  PrivateData = @{
    PSData = @{
      ProjectUri = 'https://github.com/smoonlee/oh-my-posh-profile'
      Tags = @('AKS', 'Azure', 'Kubernetes', 'Profile')
    }
  }
}
