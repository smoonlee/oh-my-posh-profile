@{
  RootModule = 'PwshProfile.TlsCertificate.psm1'
  ModuleVersion = '1.0.2'
  GUID = '8e4a9f1d-2c6b-4e0a-9f3d-7b8c1a2e5d64'
  Author = 'smoonlee'
  Description = 'Optional Pwsh Profile module for inspecting TLS certificate expiry, for remote endpoints and local certificate files.'
  PowerShellVersion = '5.1'
  FunctionsToExport = @('Get-TlsCertificate', 'Split-PfxCertificate', 'New-PfxCertificate', 'Test-CertificateKeyMatch', 'New-SelfSignedTlsCertificate')
  CmdletsToExport = @()
  VariablesToExport = @()
  AliasesToExport = @()
  FormatsToProcess = @('PwshProfile.TlsCertificate.Format.ps1xml')
  PrivateData = @{
    PSData = @{
      ProjectUri = 'https://github.com/smoonlee/oh-my-posh-profile'
      Tags = @('TLS', 'SSL', 'Certificate', 'OpenSSL', 'Profile')
    }
  }
}
