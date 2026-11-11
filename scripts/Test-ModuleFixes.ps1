[CmdletBinding()]
param([switch] $FileOperationsOnly)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
foreach ($path in @('src/Invoke-PwshProfileSetup.ps1', 'src/modules/PwshProfile.TlsCertificate/PwshProfile.TlsCertificate.psm1', 'src/modules/PwshProfile.Dns/PwshProfile.Dns.psm1')) {
  $tokens = $null; $errors = $null
  $null = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repo $path), [ref]$tokens, [ref]$errors)
  if ($errors.Count) { throw ($errors | Out-String) }
}
Import-Module (Join-Path $repo 'src/modules/PwshProfile.TlsCertificate/PwshProfile.TlsCertificate.psd1') -Force
Import-Module (Join-Path $repo 'src/modules/PwshProfile.Dns/PwshProfile.Dns.psd1') -Force
$root = Join-Path ([IO.Path]::GetTempPath()) ('module-fixes-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $root
function Assert-Throws([scriptblock]$Action, [string]$Pattern) {
  try { & $Action; throw 'Expected failure was not raised' }
  catch { if ($_.Exception.Message -notlike $Pattern) { throw } }
}
function New-LoopbackTcpListener {
  # Some CI Windows runners block loopback socket construction outright,
  # raising a misleading "network password is not correct" WinSock error.
  # That is a persistent environment restriction, not a transient fault, so
  # skip the affected sub-test instead of retrying or failing the suite.
  try { return [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0) }
  catch {
    if ($_.Exception.Message -like '*network password is not correct*') { return $null }
    throw
  }
}
try {
  $cert = New-SelfSignedTlsCertificate test.invalid -DnsName test.invalid -OutputDirectory $root
  $keyHash = (Get-FileHash $cert.PrivateKeyPath).Hash
  Assert-Throws { New-SelfSignedTlsCertificate test.invalid -OutputDirectory $root } '*Use -Force*'
  if ((Get-FileHash $cert.PrivateKeyPath).Hash -ne $keyHash) { throw 'Key was overwritten' }
  $cert = New-SelfSignedTlsCertificate test.invalid -DnsName test.invalid -OutputDirectory $root -Force
  if ((Get-FileHash $cert.PrivateKeyPath).Hash -eq $keyHash) { throw 'Force did not replace key' }
  $password = ConvertTo-SecureString 'SyntheticRegression42' -AsPlainText -Force
  $pfx = New-PfxCertificate -CertificatePath $cert.CertificatePath -PrivateKeyPath $cert.PrivateKeyPath -Password $password
  $originalPfxHash = (Get-FileHash $pfx.OutputPath).Hash
  $tls = Get-Module PwshProfile.TlsCertificate
  & $tls {
    function script:Get-Command { param($Name, $ErrorAction) [pscustomobject]@{ Name = 'Invoke-TestFailedPfxWrite' } }
    function script:Invoke-TestFailedPfxWrite {
      $destination = $args[([array]::IndexOf($args, '-out') + 1)]
      [IO.File]::WriteAllText($destination, 'Synthetic partial PFX output')
      $global:LASTEXITCODE = 1
      'Synthetic failed PFX write'
    }
  }
  try {
    Assert-Throws { New-PfxCertificate -CertificatePath $cert.CertificatePath -PrivateKeyPath $cert.PrivateKeyPath -OutputPath $pfx.OutputPath -Password $password -Force } '*OpenSSL could not create the PFX*'
    if ((Get-FileHash $pfx.OutputPath).Hash -ne $originalPfxHash) { throw 'Failed PFX creation changed the original file.' }
  } finally {
    Remove-Module PwshProfile.TlsCertificate -Force
    Import-Module (Join-Path $repo 'src/modules/PwshProfile.TlsCertificate/PwshProfile.TlsCertificate.psd1') -Force
  }
  'PASS: failed forced PFX creation preserves the original destination.'
  $split = Split-PfxCertificate $pfx.OutputPath -Password $password
  $splitHash = (Get-FileHash $split.PrivateKeyPath).Hash
  Assert-Throws { Split-PfxCertificate $pfx.OutputPath -Password $password } '*Use -Force*'
  $wrong = ConvertTo-SecureString 'WrongSyntheticPassword' -AsPlainText -Force
  Assert-Throws { Split-PfxCertificate $pfx.OutputPath -Password $wrong -Force } '*OpenSSL could not*'
  if ((Get-FileHash $split.PrivateKeyPath).Hash -ne $splitHash) { throw 'Failed split changed output' }
  $split = Split-PfxCertificate $pfx.OutputPath -Password $password -Force
  if (-not (Test-CertificateKeyMatch $split.CertificatePath $split.PrivateKeyPath -KeyPassword $password).IsMatch) { throw 'Split key mismatch' }
  $originalEncoding = $OutputEncoding.CodePage
  $unicodeText = 'Synthetic' + [char]0xE9 + 'Regression42'
  $unicodePassword = ConvertTo-SecureString $unicodeText -AsPlainText -Force
  $unicodeCert = New-SelfSignedTlsCertificate unicode.invalid -OutputDirectory $root -KeyPassword $unicodePassword -ErrorAction Stop
  $unicodePfx = New-PfxCertificate -CertificatePath $unicodeCert.CertificatePath -PrivateKeyPath $unicodeCert.PrivateKeyPath -Password $unicodePassword -KeyPassword $unicodePassword
  $unicodeSplit = Split-PfxCertificate $unicodePfx.OutputPath -Password $unicodePassword
  if (-not (Test-CertificateKeyMatch $unicodeSplit.CertificatePath $unicodeSplit.PrivateKeyPath -KeyPassword $unicodePassword).IsMatch) {
    throw 'Unicode password certificate round trip failed.'
  }
  $utf8Accepted = & {
    param($path, $passwordText)
    $OutputEncoding = [Text.UTF8Encoding]::new($false)
    $ErrorActionPreference = 'Continue'
    $PSNativeCommandUseErrorActionPreference = $false
    $null = @($passwordText + "`n") | & openssl pkcs12 -in $path -nokeys -noout -passin stdin 2>&1
    $LASTEXITCODE -eq 0
  } $unicodePfx.OutputPath $unicodeText
  if (-not $utf8Accepted) { throw 'PFX must accept the requested Unicode password as UTF-8.' }
  if ($OutputEncoding.CodePage -ne $originalEncoding) { throw 'Certificate commands changed caller output encoding.' }
  'PASS: Unicode key/PFX passwords, terminating-error handling, and caller encoding preservation.'
  $tls = Get-Module PwshProfile.TlsCertificate
  # Load the plain (password-free) certificate file rather than the PFX: some
  # CI Windows runners fail ANY password-protected PKCS12 import via
  # CryptoAPI with a misleading "network password is not correct" error,
  # regardless of key storage flags. RawData is identical either way, so
  # this still verifies fingerprint consistency between .NET and OpenSSL.
  $certificateObject = [Security.Cryptography.X509Certificates.X509Certificate2]::new($cert.CertificatePath)
  try {
    $hash = & $tls { param($cert) Get-TlsCertificateFingerprint $cert } $certificateObject
    if ($hash -ne (Get-TlsCertificate -Path $cert.CertificatePath).Thumbprint) { throw 'Fingerprint mismatch' }
  }
  finally { $certificateObject.Dispose() }
  $listener = if ($FileOperationsOnly) { $null } else { New-LoopbackTcpListener }
  if (-not $listener) {
    'SKIP: silent TLS endpoint timeout (loopback tests disabled or unavailable).'
  } else {
    $listener.Start()
    $accept = $listener.AcceptTcpClientAsync()
    $timer = [Diagnostics.Stopwatch]::StartNew()
    try {
      Assert-Throws { Get-TlsCertificate 127.0.0.1 -Port $listener.LocalEndpoint.Port -TimeoutSec 1 } '*timed out*'
      if ($timer.Elapsed.TotalSeconds -gt 5) { throw 'TLS handshake exceeded deadline' }
    }
    finally {
      if ($accept.IsCompleted) { $accept.Result.Dispose() }
      $listener.Stop()
    }
    'PASS: silent TLS endpoint is bounded by timeout.'
  }

  $listener = if ($FileOperationsOnly) { $null } else { New-LoopbackTcpListener }
  if (-not $listener) {
    'SKIP: real loopback TLS handshake (loopback tests disabled or unavailable).'
  } else {
    $listener.Start(); $port = $listener.LocalEndpoint.Port; $listener.Stop()
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = (Get-Command openssl).Source
    $info.UseShellExecute = $false; $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    foreach ($argument in @('s_server', '-quiet', '-accept', "127.0.0.1:$port", '-cert', $cert.CertificatePath, '-key', $cert.PrivateKeyPath)) { $info.ArgumentList.Add($argument) }
    $server = [Diagnostics.Process]::Start($info)
    $outDrain = $server.StandardOutput.BaseStream.CopyToAsync([IO.Stream]::Null)
    $errDrain = $server.StandardError.BaseStream.CopyToAsync([IO.Stream]::Null)
    try {
      Start-Sleep -Milliseconds 300
      $remote = Get-TlsCertificate 127.0.0.1 -Port $port -ShowChain -TimeoutSec 5
      if ($remote.Thumbprint -ne $hash -or @($remote.Chain).Count -lt 1) { throw 'Live local TLS fingerprint/chain mismatch' }
      'PASS: real loopback TLS handshake, chain data, and matching remote/file fingerprint.'
    }
    finally {
      if (-not $server.HasExited) { $server.Kill(); $null = $server.WaitForExit(1000) }
      $server.Dispose()
    }
  }
  & $tls {
    function script:Get-TlsCertificateFromEndpoint {
      [pscustomobject]@{ Subject = 'test'; Chain = @([pscustomobject]@{ Subject = 'test' }) }
    }
  }
  if (@(Get-TlsCertificate test.invalid -ShowChain).Count -ne 1 -or (Get-TlsCertificate test.invalid -ShowChain).Chain.Count -ne 1) { throw 'Chain not returned' }
  'PASS: overwrite guards, Force, failed split preservation, PFX round trip, SHA256 consistency, chain objects.'
}
finally {
  # This directory contains only this run's synthetic files; never recurse.
  Get-ChildItem -LiteralPath $root -File -Force | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
  Remove-Item -LiteralPath $root
}

Add-Type 'public enum ModuleTestDnsType { A, TXT }'
$dns = Get-Module PwshProfile.Dns
& $dns {
  function script:Get-Command {
    param($Name)
    if ($Name -eq 'Resolve-DnsName') { return [pscustomobject]@{ Parameters = @{ Type = @{ ParameterType = [ModuleTestDnsType] } } } }
    if ($Name -eq 'dig') { return [pscustomobject]@{ Name = 'Invoke-TestDig' } }
  }
  function script:Resolve-DnsName { throw 'Native resolver should not receive CAA' }
  function script:Invoke-TestDig {
    if ($args -notcontains '@192.0.2.53') { throw 'Server was not preserved' }
    $global:LASTEXITCODE = 0
    ';; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 1'
    'example.invalid. 300 IN CAA 0 issue "ca.invalid"'
  }
}
$records = @(Get-DnsResult example.invalid -RecordType CAA -Server 192.0.2.53)
if ($records.Count -ne 1 -or $records[0].Type -ne 'CAA') { throw 'CAA fallback failed' }
& $dns {
  function script:Invoke-TestDig {
    $global:LASTEXITCODE = 0
    ';; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 1'
  }
}
Assert-Throws { Get-DnsResult example.invalid -RecordType CAA } '*NXDOMAIN*'
& $dns {
  function script:Get-Command {
    param($Name)
    if ($Name -eq 'Resolve-DnsName') { [pscustomobject]@{ Parameters = @{ Type = @{ ParameterType = [ModuleTestDnsType] } } } }
  }
}
Assert-Throws { Get-DnsResult example.invalid -RecordType CAA } '*requires*dig*'
& $dns { function script:Resolve-DnsRecordSet { throw 'Synthetic resolver failure' } }
$allOutput = @(try { Get-DnsResult example.invalid -All 3>&1 } catch {
  if ($_.Exception.Message -notlike '*queries failed*') { throw }
})
if (@($allOutput | Where-Object { $_ -is [Management.Automation.WarningRecord] }).Count -ne 9) { throw 'DNS All silently hid errors' }
'PASS: CAA fallback preserves selected resolver; All reports query failures.'

Import-Module (Join-Path $repo 'src/modules/PwshProfile.AzureKubernetes/PwshProfile.AzureKubernetes.psd1') -Force
$aks = Get-Module PwshProfile.AzureKubernetes
& $aks {
  function script:Get-Command { param($Name, $ErrorAction) [pscustomobject]@{ Name = 'Invoke-TestAksCli' } }
  function script:Invoke-TestAksCli { $global:LASTEXITCODE = 0; $script:AksFixture }
}
foreach ($fixture in @(
    '{"unexpectedSchema":true}', 'null', '[]', '{"values":null}', '{"values":{}}',
    '{"values":[{}]}', '{"values":[{"patchVersions":[]}]}', '{"values":[{"patchVersions":{"invalid":{}}}]}',
    '{"orchestrators":{}}', '{"orchestrators":[{}]}'
  )) {
  & $aks { param($json) $script:AksFixture = $json } $fixture
  Assert-Throws { Get-AksVersion eastus } '*invalid AKS version response*'
}
foreach ($fixture in @('{"values":[]}', '{"values":[{"patchVersions":{}}]}', '{"orchestrators":[]}')) {
  & $aks { param($json) $script:AksFixture = $json } $fixture
  if (@(Get-AksVersion eastus).Count -ne 0) { throw 'Empty AKS version arrays must not emit blank versions.' }
}
foreach ($fixture in @(
    '{"orchestrators":[{"orchestratorVersion":"1.33.1","default":true},{"orchestratorVersion":"1.34.0","isPreview":true}]}',
    '{"values":[{"version":"1.33","isDefault":true,"patchVersions":{"1.33.1":{}}},{"version":"1.34","isPreview":true,"patchVersions":{"1.34.0":{}}}]}'
  )) {
  & $aks { param($json) $script:AksFixture = $json } $fixture
  $stable = @(Get-AksVersion eastus)
  if ($stable.Count -ne 1 -or $stable[0].KubernetesVersion -ne '1.33.1' -or -not $stable[0].IsDefault) {
    throw 'Supported AKS response schemas must preserve stable and default version flags.'
  }
  if (@(Get-AksVersion eastus -IncludePreview).Count -ne 2) { throw 'AKS preview filtering failed.' }
}
'PASS: legacy/current AKS schemas, preview flags, empty results, and malformed-response rejection.'

Import-Module (Join-Path $repo 'src/modules/PwshProfile.EndOfLife/PwshProfile.EndOfLife.psd1') -Force
Import-Module (Join-Path $repo 'src/modules/PwshProfile.AzureImages/PwshProfile.AzureImages.psd1') -Force
$eol = Get-Module PwshProfile.EndOfLife
$images = Get-Module PwshProfile.AzureImages
foreach ($case in @(
    @{ Value = '2026-11-10'; Expected = $false },
    @{ Value = '2026-11-11'; Expected = $true },
    @{ Value = '2026-11-12'; Expected = $true },
    @{ Value = $false; Expected = $true },
    @{ Value = $true; Expected = $false }
  )) {
  $generic = & $eol { param($value) Test-EndOfLifeDateIsActive -Value $value -CurrentDate ([datetime]'2026-11-11') } $case.Value
  $image = & $images {
    param($value)
    $original = $script:AzureImagesCatalog.Lifecycles
    try {
      $script:AzureImagesCatalog.Lifecycles = @([pscustomobject]@{ Product = 'ubuntu'; Cycle = '24.04'; ReleaseDate = '2024-04-25'; Eol = $value })
      Test-AzureImageSupported -Publisher Canonical -Offer ubuntu-24_04-lts -Sku server -Catalog -CurrentDate ([datetime]'2026-11-11')
    } finally { $script:AzureImagesCatalog.Lifecycles = $original }
  } $case.Value
  if ($generic -ne $case.Expected -or $image -ne $case.Expected) {
    throw "Lifecycle date boundary mismatch for '$($case.Value)'."
  }
}
'PASS: EOL and Azure Images agree before, on and after the inclusive EOL date and on boolean lifecycle values.'
