@{
    RootModule        = 'PwshProfile.AzureImages.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '8718491f-9629-4aeb-ae5a-d0563ad75628'
    Author            = 'smoonlee'
    Description       = 'Optional Pwsh Profile module for discovering Azure VM images and formatting Bicep image references.'
    PowerShellVersion = '5.1'
    FormatsToProcess  = @('PwshProfile.AzureImages.Format.ps1xml')
    FunctionsToExport = @('Get-AzureVmImage', 'ConvertTo-AzureVmImageBicep')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            ProjectUri = 'https://github.com/smoonlee/oh-my-posh-profile'
            Tags       = @('Azure', 'Images', 'Bicep', 'Profile')
        }
    }
}
