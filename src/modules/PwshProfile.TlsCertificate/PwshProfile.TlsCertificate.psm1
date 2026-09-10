function Get-TlsCertificateFingerprint {
  param([System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate)
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  try { ([BitConverter]::ToString($sha256.ComputeHash($Certificate.RawData))).Replace('-', '') }
  finally { $sha256.Dispose() }
}

function Invoke-TlsCertificateFileTransaction {
  param([string[]] $Paths, [switch] $Force, [scriptblock] $Action)
  $staged = @{}
  $backups = @{}
  $committed = [System.Collections.Generic.List[string]]::new()
  foreach ($path in $Paths) {
    if (Test-Path -LiteralPath $path) {
      if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Output is not a file: '$path'." }
      if (-not $Force) { throw "'$path' already exists. Use -Force to overwrite it." }
    }
    $staged[$path] = Join-Path (Split-Path $path -Parent) ('.' + [guid]::NewGuid().ToString('N') + '.pem')
  }
  try {
    & $Action $staged
    foreach ($path in $Paths) {
      # An optional chain may be empty, but must still be staged successfully.
      if (-not (Test-Path -LiteralPath $staged[$path] -PathType Leaf)) { throw "Certificate output was not created: '$path'." }
    }
    foreach ($path in $Paths) {
      if (Test-Path -LiteralPath $path) {
        if (-not $Force) { throw "'$path' appeared during generation. Use -Force to overwrite it." }
        $backups[$path] = "$($staged[$path]).bak"
        [IO.File]::Replace($staged[$path], $path, $backups[$path])
      } else { [IO.File]::Move($staged[$path], $path) }
      $committed.Add($path)
    }
  } catch {
    $failure = $_
    $rollbackErrors = @()
    foreach ($path in $committed) {
      try {
        if ($backups.ContainsKey($path)) { [IO.File]::Copy($backups[$path], $path, $true) }
        else { [IO.File]::Delete($path) }
      } catch { $rollbackErrors += $_.Exception.Message }
    }
    if ($rollbackErrors.Count) {
      # Retain recovery copies if rollback was not completely successful.
      $backups = @{}
      throw "Certificate write failed: $($failure.Exception.Message) Rollback also failed: $($rollbackErrors -join '; '). Recovery .bak files were retained."
    }
    throw $failure
  } finally {
    foreach ($file in @($staged.Values) + @($backups.Values)) {
      Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
    }
  }
}

function New-TlsCertificateResult {
  # Builds the common output object shape for both remote and local certificate lookups.
  param (
    [Parameter(Mandatory)]
    [string] $Source,

    [Parameter(Mandatory)]
    [string] $Subject,

    [Parameter(Mandatory)]
    [string] $Issuer,

    [Parameter(Mandatory)]
    [datetime] $NotBefore,

    [Parameter(Mandatory)]
    [datetime] $NotAfter,

    [string] $Thumbprint,

    [AllowNull()]
    [string] $Protocol,

    [AllowNull()]
    [object[]] $Chain
  )

  $daysRemaining = [int][Math]::Floor(($NotAfter - (Get-Date)).TotalDays)

  [pscustomobject][ordered]@{
    PSTypeName          = 'PwshProfile.TlsCertificate.Result'
    Source              = $Source
    Subject             = $Subject
    Issuer              = $Issuer
    NotBefore           = $NotBefore
    NotAfter            = $NotAfter
    DaysRemaining       = $daysRemaining
    IsExpired           = $daysRemaining -lt 0
    Thumbprint          = $Thumbprint
    ThumbprintAlgorithm = 'SHA256'
    Protocol            = $Protocol
    Chain               = $Chain
  }
}

function Get-TlsCertificateCommonName {
  # Extracts just the CN= value from a full distinguished name, falling back to the raw value.
  param (
    [Parameter(Mandatory)]
    [AllowEmptyString()]
    [string] $DistinguishedName
  )

  if ($DistinguishedName -match 'CN=(?<cn>[^,]+)') {
    return $Matches.cn
  }

  $DistinguishedName
}

function ConvertTo-TlsCertificateChainLink {
  # Converts X509ChainElement entries captured during a handshake into a reportable chain-of-trust view.
  param (
    [Parameter(Mandatory)]
    [System.Collections.Generic.List[System.Security.Cryptography.X509Certificates.X509ChainElement]] $ChainElements
  )

  for ($index = 0; $index -lt $ChainElements.Count; $index++) {
    $element = $ChainElements[$index]
    $certificate = $element.Certificate
    $statusFlags = @($element.ChainElementStatus | ForEach-Object { $_.Status }) -join ', '

    [pscustomobject]@{
      PSTypeName          = 'PwshProfile.TlsCertificate.ChainLink'
      Position            = $index
      Subject             = $certificate.Subject
      SubjectCommonName   = Get-TlsCertificateCommonName -DistinguishedName $certificate.Subject
      Issuer              = $certificate.Issuer
      IssuerCommonName    = Get-TlsCertificateCommonName -DistinguishedName $certificate.Issuer
      NotBefore           = $certificate.NotBefore
      NotAfter            = $certificate.NotAfter
      DaysRemaining       = [int][Math]::Floor(($certificate.NotAfter - (Get-Date)).TotalDays)
      Thumbprint          = Get-TlsCertificateFingerprint -Certificate $certificate
      ThumbprintAlgorithm = 'SHA256'
      IsRoot              = $certificate.Subject -eq $certificate.Issuer
      StatusFlags         = if ($statusFlags) { $statusFlags } else { 'NoError' }
    }
  }
}

function Get-TlsCertificateFromEndpoint {
  param (
    [Parameter(Mandatory)]
    [string] $HostName,

    [Parameter(Mandatory)]
    [int] $Port,

    [Parameter(Mandatory)]
    [int] $TimeoutSec,

    [switch] $ShowChain
  )

  $tcpClient = [System.Net.Sockets.TcpClient]::new()
  $certificate = $null
  $deadline = $null
  $stopwatch = [Diagnostics.Stopwatch]::StartNew()
  $sslStream = $null
  $capturedChain = [System.Collections.Generic.List[System.Security.Cryptography.X509Certificates.X509ChainElement]]::new()
  try {
    $connectTask = $tcpClient.ConnectAsync($HostName, $Port)
    if (-not $connectTask.Wait([TimeSpan]::FromSeconds($TimeoutSec))) {
      throw "Connection to '$HostName`:$Port' timed out after $TimeoutSec seconds."
    }

    $validationCallback = {
      param($sender, $certificate, $chain, $sslPolicyErrors)
      $capturedChain.Clear()
      if ($chain -and $chain.ChainElements) {
        foreach ($element in $chain.ChainElements) {
          $capturedChain.Add($element)
        }
      }
      $true
    }.GetNewClosure()

    $sslStream = [System.Net.Security.SslStream]::new($tcpClient.GetStream(), $false, $validationCallback)
    # Keep the PowerShell validation callback on this thread. A managed timer
    # closes the socket at the deadline, including a stalled TLS handshake.
    if (-not ('PwshProfile.TlsDeadline' -as [type])) {
      Add-Type -TypeDefinition @'
namespace PwshProfile {
    public sealed class TlsDeadline : System.IDisposable {
        private readonly System.Threading.Timer timer;
        public volatile bool Expired;
        public TlsDeadline(System.Net.Sockets.TcpClient client, int milliseconds) {
            timer = new System.Threading.Timer(delegate(object state) {
                Expired = true;
                try { client.Close(); } catch (System.ObjectDisposedException) { }
            }, null, milliseconds, System.Threading.Timeout.Infinite);
        }
        public void Dispose() { timer.Dispose(); }
    }
}
'@
    }
    $remaining = [int][Math]::Max(1, ($TimeoutSec * 1000) - $stopwatch.ElapsedMilliseconds)
    $deadline = [PwshProfile.TlsDeadline]::new($tcpClient, $remaining)
    try { $sslStream.AuthenticateAsClient($HostName) }
    catch {
      if ($deadline.Expired) { throw "TLS handshake with '$HostName`:$Port' timed out after $TimeoutSec seconds." }
      throw
    } finally { $deadline.Dispose() }

    $remoteCertificate = $sslStream.RemoteCertificate
    if (-not $remoteCertificate) {
      throw "No certificate was returned by '$HostName`:$Port'."
    }

    $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($remoteCertificate)
    $chainLinks = if ($ShowChain -and $capturedChain.Count -gt 0) {
      @(ConvertTo-TlsCertificateChainLink -ChainElements $capturedChain)
    } else {
      $null
    }

    New-TlsCertificateResult `
      -Source "$HostName`:$Port" `
      -Subject $certificate.Subject `
      -Issuer $certificate.Issuer `
      -NotBefore $certificate.NotBefore `
      -NotAfter $certificate.NotAfter `
      -Thumbprint (Get-TlsCertificateFingerprint -Certificate $certificate) `
      -Protocol ([string]$sslStream.SslProtocol) `
      -Chain $chainLinks
  } finally {
    if ($deadline) { $deadline.Dispose() }
    if ($certificate) { $certificate.Dispose() }
    if ($sslStream) { $sslStream.Dispose() }
    $tcpClient.Dispose()
  }
}

function Get-TlsCertificateFromFile {
  param (
    [Parameter(Mandatory)]
    [string] $Path
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Certificate file not found: '$Path'."
  }

  $opensslCommand = Get-Command -Name openssl -ErrorAction Ignore
  if (-not $opensslCommand) {
    throw 'OpenSSL was not found. Install FireDaemon.OpenSSL (winget) then run the command again.'
  }

  $arguments = @('x509', '-in', $Path, '-noout', '-subject', '-issuer', '-startdate', '-enddate', '-fingerprint', '-sha256', '-nameopt', 'oneline')
  $output = & $opensslCommand.Name @arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "OpenSSL could not parse certificate '$Path'. $(($output | Out-String).Trim())"
  }

  $subject = ($output | Where-Object { $_ -match '^subject\s*=' }) -replace '^subject\s*=\s*', ''
  $issuer = ($output | Where-Object { $_ -match '^issuer\s*=' }) -replace '^issuer\s*=\s*', ''
  $notBeforeText = ($output | Where-Object { $_ -match '^notBefore=' }) -replace '^notBefore=', ''
  $notAfterText = ($output | Where-Object { $_ -match '^notAfter=' }) -replace '^notAfter=', ''
  $fingerprintText = ($output | Where-Object { $_ -match 'Fingerprint=' }) -replace '^.*Fingerprint=', ''

  try {
    $notBeforeNormalized = ($notBeforeText.Trim() -replace '\s+', ' ')
    $notAfterNormalized = ($notAfterText.Trim() -replace '\s+', ' ')
    [string[]] $dateFormats = @('MMM d HH:mm:ss yyyy ''GMT''', 'MMM d HH:mm:ss yyyy')
    $notBefore = [datetime]::ParseExact($notBeforeNormalized, $dateFormats, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)
    $notAfter = [datetime]::ParseExact($notAfterNormalized, $dateFormats, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)
  } catch {
    throw "Could not parse certificate dates from OpenSSL output for '$Path'. $($_.Exception.Message)"
  }

  New-TlsCertificateResult `
    -Source $Path `
    -Subject $subject.Trim() `
    -Issuer $issuer.Trim() `
    -NotBefore $notBefore `
    -NotAfter $notAfter `
    -Thumbprint ($fingerprintText.Trim() -replace ':', '') `
    -Protocol $null
}

function Get-TlsCertificate {
  <#
  .SYNOPSIS
      Gets TLS certificate details and expiry information.

  .DESCRIPTION
      Connects to a remote host and port to retrieve its TLS certificate, or
      reads a local certificate file. Reports Subject, Issuer, validity dates,
      days remaining until expiry, and thumbprint. Remote lookups use .NET's
      SslStream directly. Local file lookups use OpenSSL (FireDaemon.OpenSSL),
      since PEM-encoded certificates are not natively readable in Windows
      PowerShell 5.1.

  .PARAMETER HostName
      Remote host name to connect to, such as example.com.

  .PARAMETER Port
      TCP port to connect to. Defaults to 443.

  .PARAMETER TimeoutSec
      Deadline for TCP connection and TLS handshake. Defaults to 5 seconds.

  .PARAMETER ShowChain
      Print the chain inspected by .NET during the handshake, including each
      link's subject, issuer, and validity, and populate the returned object's
      Chain property with the same links. The local trust store may supply
      certificates in this chain.

  .PARAMETER Path
      Path to a local certificate file (for example .pem, .crt, .cer) to inspect
      instead of connecting to a remote host.

  .EXAMPLE
      Get-TlsCertificate -HostName example.com

  .EXAMPLE
      Get-TlsCertificate -HostName https://example.com

  .EXAMPLE
      Get-TlsCertificate -HostName example.com -ShowChain

  .EXAMPLE
      Get-TlsCertificate -HostName example.com -Port 8443

  .EXAMPLE
      Get-TlsCertificate -Path C:\certs\example.pem
  #>
  [CmdletBinding(DefaultParameterSetName = 'Remote')]
  [OutputType([pscustomobject])]
  param (
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Remote')]
    [ValidateNotNullOrEmpty()]
    [string] $HostName,

    [Parameter(ParameterSetName = 'Remote')]
    [ValidateRange(1, 65535)]
    [int] $Port = 443,

    [Parameter(ParameterSetName = 'Remote')]
    [ValidateRange(1, 60)]
    [int] $TimeoutSec = 5,

    [Parameter(ParameterSetName = 'Remote')]
    [switch] $ShowChain,

    [Parameter(Mandatory, ParameterSetName = 'LocalFile')]
    [ValidateNotNullOrEmpty()]
    [string] $Path
  )

  if ($PSCmdlet.ParameterSetName -eq 'LocalFile') {
    Get-TlsCertificateFromFile -Path $Path
    return
  }

  $resolvedHostName = $HostName
  $resolvedPort = $Port
  if ($resolvedHostName -match '^[a-zA-Z][a-zA-Z0-9+.-]*://') {
    try {
      $parsedUri = [uri]$resolvedHostName
    } catch {
      throw "'$HostName' could not be parsed as a host name or URL."
    }

    $resolvedHostName = $parsedUri.Host
    if (-not $PSBoundParameters.ContainsKey('Port') -and $parsedUri.Port -gt 0) {
      $resolvedPort = $parsedUri.Port
    }
  }

  $result = Get-TlsCertificateFromEndpoint -HostName $resolvedHostName -Port $resolvedPort -TimeoutSec $TimeoutSec -ShowChain:$ShowChain

  $result
  if ($ShowChain) {
    # The default table view for Result never renders Chain; print it explicitly.
    if ($result.Chain) {
      $result.Chain | Format-Table | Out-Host
    } else {
      Write-Warning "No certificate chain was captured for '$($result.Source)'."
    }
  }
}

function Split-PfxCertificate {
  <#
  .SYNOPSIS
      Splits a PFX/P12 file into private key, certificate, and intermediate
      chain files.

  .DESCRIPTION
      Uses OpenSSL (FireDaemon.OpenSSL) to extract the private key, the leaf
      certificate, and any intermediate ("chain") certificates from a PKCS#12
      (.pfx/.p12) file into separate PEM files. The import password, and any
      output key password, are passed to OpenSSL over stdin rather than as
      command-line arguments, so they are not exposed in the process list.

      By default the extracted private key is re-encrypted with the same
      password used to import the PFX. Use -NoKeyPassword to write an
      unencrypted private key instead; this is written to disk in plain text,
      so restrict its file permissions immediately.

  .PARAMETER Path
      Path to the source .pfx or .p12 file.

  .PARAMETER Password
      Import password for the PFX file, as a SecureString. Omit for PFX files
      that have no password.

  .PARAMETER OutputDirectory
      Directory to write the extracted files to. Defaults to the same
      directory as -Path.

  .PARAMETER NoKeyPassword
      Write the extracted private key unencrypted instead of re-encrypting it
      with -Password.

  .PARAMETER Force
      Overwrite existing output files only after all extractions succeed.

  .EXAMPLE
      Split-PfxCertificate -Path C:\certs\example.pfx -Password (Read-Host -AsSecureString)

  .EXAMPLE
      Split-PfxCertificate -Path C:\certs\example.pfx -Password $securePassword -OutputDirectory C:\certs\split -NoKeyPassword
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param (
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string] $Path,

    [System.Security.SecureString] $Password,

    [ValidateNotNullOrEmpty()]
    [string] $OutputDirectory,

    [switch] $NoKeyPassword,

    [switch] $Force
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "PFX file not found: '$Path'."
  }

  $opensslCommand = Get-Command -Name openssl -ErrorAction Ignore
  if (-not $opensslCommand) {
    throw 'OpenSSL was not found. Install FireDaemon.OpenSSL (winget) then run the command again.'
  }

  $resolvedPath = (Resolve-Path -LiteralPath $Path).ProviderPath
  if (-not $PSBoundParameters.ContainsKey('OutputDirectory')) {
    $OutputDirectory = Split-Path -Path $resolvedPath -Parent
  }
  if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
  }

  $OutputDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
  $baseName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedPath)
  $keyPath = Join-Path $OutputDirectory "$baseName.key.pem"
  $certPath = Join-Path $OutputDirectory "$baseName.crt.pem"
  $chainPath = Join-Path $OutputDirectory "$baseName.chain.pem"

  $plainPassword = if ($PSBoundParameters.ContainsKey('Password')) {
    [System.Net.NetworkCredential]::new('', $Password).Password
  } else {
    ''
  }

  $outputPaths = @{ Key = $keyPath; Certificate = $certPath; Chain = $chainPath }
  Invoke-TlsCertificateFileTransaction -Paths @($keyPath, $certPath, $chainPath) -Force:$Force -Action {
    param($staged)
    $keyPath = $staged[$outputPaths.Key]
    $certPath = $staged[$outputPaths.Certificate]
    $chainPath = $staged[$outputPaths.Chain]
    $certOutput = @($plainPassword) | & $opensslCommand.Name pkcs12 -in $resolvedPath -clcerts -nokeys -out $certPath -passin stdin 2>&1
    if ($LASTEXITCODE -ne 0) {
      throw "OpenSSL could not extract the certificate from '$resolvedPath'. $(($certOutput | Out-String).Trim())"
    }

    $chainOutput = @($plainPassword) | & $opensslCommand.Name pkcs12 -in $resolvedPath -cacerts -nokeys -chain -out $chainPath -passin stdin 2>&1
    if ($LASTEXITCODE -ne 0) {
      throw "OpenSSL could not extract the certificate chain from '$resolvedPath'. $(($chainOutput | Out-String).Trim())"
    }

    if ($NoKeyPassword) {
      $keyOutput = @($plainPassword) | & $opensslCommand.Name pkcs12 -in $resolvedPath -nocerts -nodes -out $keyPath -passin stdin 2>&1
    } else {
      $keyOutput = @($plainPassword, $plainPassword) | & $opensslCommand.Name pkcs12 -in $resolvedPath -nocerts -out $keyPath -passin stdin -passout stdin 2>&1
    }
    if ($LASTEXITCODE -ne 0) {
      throw "OpenSSL could not extract the private key from '$resolvedPath'. $(($keyOutput | Out-String).Trim())"
    }

  }
  if ($NoKeyPassword) {
    Write-Warning "Private key written unencrypted to '$keyPath'. Restrict its file permissions immediately."
  }

  [pscustomobject][ordered]@{
    PSTypeName          = 'PwshProfile.TlsCertificate.PfxSplitResult'
    Source              = $resolvedPath
    PrivateKeyPath      = $keyPath
    CertificatePath     = $certPath
    ChainPath           = if ((Test-Path -LiteralPath $chainPath) -and (Get-Content -LiteralPath $chainPath -Raw)) { $chainPath } else { $null }
    PrivateKeyEncrypted = -not $NoKeyPassword
  }
}

function New-PfxCertificate {
  <#
  .SYNOPSIS
      Creates a PFX/P12 file from a certificate, private key, and optional
      intermediate chain.

  .DESCRIPTION
      Uses OpenSSL (FireDaemon.OpenSSL) to package a certificate and its
      private key (and, optionally, an intermediate chain) into a single
      password-protected PKCS#12 (.pfx) file. Passwords are passed to OpenSSL
      over stdin rather than as command-line arguments, so they are not
      exposed in the process list.

  .PARAMETER CertificatePath
      Path to the PEM-encoded certificate file.

  .PARAMETER PrivateKeyPath
      Path to the PEM-encoded private key file matching the certificate.

  .PARAMETER ChainPath
      Path to a PEM-encoded intermediate certificate chain to include.

  .PARAMETER OutputPath
      Path to write the resulting .pfx file to. Defaults to the certificate
      file's name with a .pfx extension, in the same directory.

  .PARAMETER Password
      Password to protect the resulting PFX file with, as a SecureString.

  .PARAMETER KeyPassword
      Password for -PrivateKeyPath, as a SecureString, if the private key
      file is itself encrypted.

  .PARAMETER Force
      Overwrite -OutputPath if it already exists.

  .EXAMPLE
      New-PfxCertificate -CertificatePath cert.pem -PrivateKeyPath key.pem -Password (Read-Host -AsSecureString)

  .EXAMPLE
      New-PfxCertificate -CertificatePath cert.pem -PrivateKeyPath key.pem -ChainPath chain.pem -OutputPath C:\certs\bundle.pfx -Password $securePassword
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $CertificatePath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $PrivateKeyPath,

    [ValidateNotNullOrEmpty()]
    [string] $ChainPath,

    [ValidateNotNullOrEmpty()]
    [string] $OutputPath,

    [Parameter(Mandatory)]
    [System.Security.SecureString] $Password,

    [System.Security.SecureString] $KeyPassword,

    [switch] $Force
  )

  foreach ($pathToCheck in @(
      @{ Label = 'Certificate'; Path = $CertificatePath },
      @{ Label = 'Private key'; Path = $PrivateKeyPath }
    )) {
    if (-not (Test-Path -LiteralPath $pathToCheck.Path -PathType Leaf)) {
      throw "$($pathToCheck.Label) file not found: '$($pathToCheck.Path)'."
    }
  }
  if ($PSBoundParameters.ContainsKey('ChainPath') -and -not (Test-Path -LiteralPath $ChainPath -PathType Leaf)) {
    throw "Chain file not found: '$ChainPath'."
  }

  $opensslCommand = Get-Command -Name openssl -ErrorAction Ignore
  if (-not $opensslCommand) {
    throw 'OpenSSL was not found. Install FireDaemon.OpenSSL (winget) then run the command again.'
  }

  $resolvedCertPath = (Resolve-Path -LiteralPath $CertificatePath).ProviderPath
  $resolvedKeyPath = (Resolve-Path -LiteralPath $PrivateKeyPath).ProviderPath
  $resolvedChainPath = if ($PSBoundParameters.ContainsKey('ChainPath')) {
    (Resolve-Path -LiteralPath $ChainPath).ProviderPath
  } else {
    $null
  }

  if (-not $PSBoundParameters.ContainsKey('OutputPath')) {
    $outputDirectory = Split-Path -Path $resolvedCertPath -Parent
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedCertPath)
    $OutputPath = Join-Path $outputDirectory "$baseName.pfx"
  }
  if ((Test-Path -LiteralPath $OutputPath -PathType Leaf) -and -not $Force) {
    throw "'$OutputPath' already exists. Use -Force to overwrite it."
  }

  $plainPassword = [System.Net.NetworkCredential]::new('', $Password).Password

  $arguments = @('pkcs12', '-export', '-inkey', $resolvedKeyPath, '-in', $resolvedCertPath, '-out', $OutputPath)
  if ($resolvedChainPath) {
    $arguments += @('-certfile', $resolvedChainPath)
  }

  $stdinLines = @()
  if ($PSBoundParameters.ContainsKey('KeyPassword')) {
    $arguments += @('-passin', 'stdin')
    $stdinLines += [System.Net.NetworkCredential]::new('', $KeyPassword).Password
  }
  $arguments += @('-passout', 'stdin')
  $stdinLines += $plainPassword

  $output = @($stdinLines) | & $opensslCommand.Name @arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "OpenSSL could not create the PFX file at '$OutputPath'. $(($output | Out-String).Trim())"
  }

  [pscustomobject][ordered]@{
    PSTypeName      = 'PwshProfile.TlsCertificate.PfxCreateResult'
    OutputPath      = $OutputPath
    CertificatePath = $resolvedCertPath
    PrivateKeyPath  = $resolvedKeyPath
    ChainPath       = $resolvedChainPath
  }
}

function Test-CertificateKeyMatch {
  <#
  .SYNOPSIS
      Tests whether a certificate and private key belong to the same key pair.

  .DESCRIPTION
      Compares the public key embedded in a certificate against the public key
      derived from a private key. This is the OpenSSL-equivalent of the common
      "does this cert match this key" troubleshooting check, and works for
      both RSA and EC keys.

  .PARAMETER CertificatePath
      Path to the PEM-encoded certificate file.

  .PARAMETER PrivateKeyPath
      Path to the PEM-encoded private key file.

  .PARAMETER KeyPassword
      Password for -PrivateKeyPath, as a SecureString, if the private key
      file is itself encrypted.

  .EXAMPLE
      Test-CertificateKeyMatch -CertificatePath cert.pem -PrivateKeyPath key.pem

  .EXAMPLE
      Test-CertificateKeyMatch -CertificatePath cert.pem -PrivateKeyPath key.pem -KeyPassword $securePassword
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param (
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string] $CertificatePath,

    [Parameter(Mandatory, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [string] $PrivateKeyPath,

    [System.Security.SecureString] $KeyPassword
  )

  foreach ($pathToCheck in @(
      @{ Label = 'Certificate'; Path = $CertificatePath },
      @{ Label = 'Private key'; Path = $PrivateKeyPath }
    )) {
    if (-not (Test-Path -LiteralPath $pathToCheck.Path -PathType Leaf)) {
      throw "$($pathToCheck.Label) file not found: '$($pathToCheck.Path)'."
    }
  }

  $opensslCommand = Get-Command -Name openssl -ErrorAction Ignore
  if (-not $opensslCommand) {
    throw 'OpenSSL was not found. Install FireDaemon.OpenSSL (winget) then run the command again.'
  }

  $resolvedCertPath = (Resolve-Path -LiteralPath $CertificatePath).ProviderPath
  $resolvedKeyPath = (Resolve-Path -LiteralPath $PrivateKeyPath).ProviderPath

  $certPublicKeyOutput = & $opensslCommand.Name x509 -in $resolvedCertPath -noout -pubkey 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "OpenSSL could not read the public key from '$resolvedCertPath'. $(($certPublicKeyOutput | Out-String).Trim())"
  }

  $keyArguments = @('pkey', '-in', $resolvedKeyPath, '-pubout')
  $stdinLines = @()
  if ($PSBoundParameters.ContainsKey('KeyPassword')) {
    $keyArguments += @('-passin', 'stdin')
    $stdinLines += [System.Net.NetworkCredential]::new('', $KeyPassword).Password
  }
  $keyPublicKeyOutput = @($stdinLines) | & $opensslCommand.Name @keyArguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "OpenSSL could not read the public key from '$resolvedKeyPath'. $(($keyPublicKeyOutput | Out-String).Trim())"
  }

  $normalizeText = { param($lines) (($lines | Out-String) -replace "`r`n", "`n").Trim() }
  $isMatch = (& $normalizeText $certPublicKeyOutput) -eq (& $normalizeText $keyPublicKeyOutput)

  [pscustomobject][ordered]@{
    PSTypeName      = 'PwshProfile.TlsCertificate.KeyMatchResult'
    CertificatePath = $resolvedCertPath
    PrivateKeyPath  = $resolvedKeyPath
    IsMatch         = $isMatch
  }
}

function New-SelfSignedTlsCertificate {
  <#
  .SYNOPSIS
      Creates a self-signed certificate and private key for local development
      or testing.

  .DESCRIPTION
      Uses OpenSSL (FireDaemon.OpenSSL) to generate a self-signed certificate
      and matching private key. Named New-SelfSignedTlsCertificate to avoid
      colliding with the built-in PKI module's New-SelfSignedCertificate,
      which writes to the certificate store instead of PEM files.

  .PARAMETER CommonName
      Certificate common name (CN), such as dev.local or *.dev.local.

  .PARAMETER DnsName
      Subject Alternative Names (SANs) to include on the certificate.

  .PARAMETER Days
      Number of days the certificate is valid for. Defaults to 365.

  .PARAMETER KeySize
      RSA key size in bits. Defaults to 2048.

  .PARAMETER OutputDirectory
      Directory to write the certificate and key files to. Defaults to the
      current directory.

  .PARAMETER KeyPassword
      Password to encrypt the private key with, as a SecureString. When
      omitted, the private key is written unencrypted.

  .PARAMETER Force
      Overwrite existing certificate and key files after successful generation.

  .EXAMPLE
      New-SelfSignedTlsCertificate -CommonName dev.local

  .EXAMPLE
      New-SelfSignedTlsCertificate -CommonName dev.local -DnsName dev.local,localhost -Days 30
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param (
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string] $CommonName,

    [string[]] $DnsName,

    [ValidateRange(1, 3650)]
    [int] $Days = 365,

    [ValidateSet(2048, 3072, 4096)]
    [int] $KeySize = 2048,

    [ValidateNotNullOrEmpty()]
    [string] $OutputDirectory,

    [System.Security.SecureString] $KeyPassword,

    [switch] $Force
  )

  $opensslCommand = Get-Command -Name openssl -ErrorAction Ignore
  if (-not $opensslCommand) {
    throw 'OpenSSL was not found. Install FireDaemon.OpenSSL (winget) then run the command again.'
  }

  if (-not $PSBoundParameters.ContainsKey('OutputDirectory')) {
    $OutputDirectory = (Get-Location).ProviderPath
  }
  if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
  }

  $OutputDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
  $safeName = ($CommonName -replace '[\\/:*?"<>|]', '_') -replace '^_+', 'wildcard'
  $keyPath = Join-Path $OutputDirectory "$safeName.key.pem"
  $certPath = Join-Path $OutputDirectory "$safeName.crt.pem"

  $arguments = @(
    'req', '-x509', '-newkey', "rsa:$KeySize",
    '-keyout', $keyPath, '-out', $certPath,
    '-days', $Days, '-subj', "/CN=$CommonName"
  )

  $sanEntries = @()
  if ($PSBoundParameters.ContainsKey('DnsName')) {
    $sanEntries = @($DnsName | ForEach-Object { "DNS:$_" })
  }
  if ($sanEntries.Count -gt 0) {
    $arguments += @('-addext', "subjectAltName=$($sanEntries -join ',')")
  }

  $stdinLines = @()
  if ($PSBoundParameters.ContainsKey('KeyPassword')) {
    $arguments += @('-passout', 'stdin')
    $stdinLines += [System.Net.NetworkCredential]::new('', $KeyPassword).Password
  } else {
    $arguments += '-nodes'
  }

  Invoke-TlsCertificateFileTransaction -Paths @($keyPath, $certPath) -Force:$Force -Action {
    param($staged)
    $stagedArguments = @($arguments | ForEach-Object {
        if ($_ -eq $keyPath) { $staged[$keyPath] }
        elseif ($_ -eq $certPath) { $staged[$certPath] }
        else { $_ }
      })
    $output = @($stdinLines) | & $opensslCommand.Name @stagedArguments 2>&1
    if ($LASTEXITCODE -ne 0) {
      throw "OpenSSL could not create a self-signed certificate for '$CommonName'. $(($output | Out-String).Trim())"
    }

  }

  $certInfo = Get-TlsCertificateFromFile -Path $certPath

  [pscustomobject][ordered]@{
    PSTypeName          = 'PwshProfile.TlsCertificate.SelfSignedResult'
    CertificatePath     = $certPath
    PrivateKeyPath      = $keyPath
    Subject             = $certInfo.Subject
    DnsNames            = @($sanEntries -replace '^DNS:', '')
    NotBefore           = $certInfo.NotBefore
    NotAfter            = $certInfo.NotAfter
    DaysRemaining       = $certInfo.DaysRemaining
    Thumbprint          = $certInfo.Thumbprint
    ThumbprintAlgorithm = 'SHA256'
    KeyEncrypted        = $PSBoundParameters.ContainsKey('KeyPassword')
  }
}

Export-ModuleMember -Function Get-TlsCertificate, Split-PfxCertificate, New-PfxCertificate, Test-CertificateKeyMatch, New-SelfSignedTlsCertificate
