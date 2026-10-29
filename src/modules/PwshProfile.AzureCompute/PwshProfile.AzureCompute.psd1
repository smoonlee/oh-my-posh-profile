@{
    RootModule        = 'PwshProfile.AzureCompute.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'e543219a-c574-49be-81d9-ae25ae5cdb46'
    Author            = 'smoonlee'
    Description       = 'Optional Pwsh Profile module for discovering regional Azure VM sizes, capabilities and subscription restrictions.'
    PowerShellVersion = '5.1'
    FormatsToProcess  = @('PwshProfile.AzureCompute.Format.ps1xml')
    FunctionsToExport = @('Get-AzureVmSize')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            ProjectUri = 'https://github.com/smoonlee/oh-my-posh-profile'
            Tags       = @('Azure', 'Compute', 'VirtualMachines', 'Profile')
        }
    }
}
