[CmdletBinding()]
param (
  # This region is refreshed by scripts/Update-NerdFontsCatalog.ps1.
  # BEGIN GENERATED NERD FONT VALIDATESET
  [ValidateSet(
    '0xProto',
    '3270',
    'AdwaitaMono',
    'Agave',
    'AnnotationM',
    'AnonymicePro',
    'Arimo',
    'AtkynsonMono',
    'AurulentSansM',
    'BigBlueTerm',
    'BitstromWera',
    'BlexMono',
    'CaskaydiaCove',
    'CaskaydiaMono',
    'CodeNewRoman',
    'ComicShannsMono',
    'CommitMono',
    'Cousine',
    'D2KodingLigature',
    'DaddyTimeMono',
    'DejaVuSansM',
    'DepartureMono',
    'DroidSansM',
    'EnvyCodeR',
    'FantasqueSansM',
    'FiraCode',
    'FiraMono',
    'GeistMono',
    'GohuFont',
    'GoMono',
    'GoogleSansCode',
    'Hack',
    'Hasklug',
    'HeavyData',
    'Hurmit',
    'iMWriting',
    'Inconsolata',
    'Inconsolata LGC',
    'InconsolataGo',
    'IntoneMono',
    'Iosevka',
    'IosevkaTerm',
    'IosevkaTermSlab',
    'JetBrainsMono',
    'Lekton',
    'Lilex',
    'LiterationMono',
    'M+',
    'MartianMono',
    'MesloLG',
    'Monaspice',
    'Monofur',
    'Monoid',
    'Mononoki',
    'Noto',
    'OpenDyslexic',
    'Overpass',
    'ProFont',
    'ProggyClean',
    'RecMono',
    'RobotoMono',
    'SauceCodePro',
    'ShureTechMono',
    'SpaceMono',
    'Symbols',
    'Terminess',
    'Tinos',
    'Ubuntu',
    'UbuntuMono',
    'UbuntuSans',
    'VictorMono',
    'ZedMono'
  )]
  [Parameter(Position = 0)]
  [Alias('NerdFont')]
  [string] $nerdFontName = ''
  # END GENERATED NERD FONT VALIDATESET

  ,
  [ValidateSet('All', 'NerdFont', 'Winget', 'Modules', 'Profile', 'ProfileUpdate')]
  [string] $RunPhase = 'All',

  [switch] $Reset,

  [switch] $Prerelease,

  [switch] $LocalSource
)

# ! HELP Write-PwshProfileStatus - Writes the status of the current profile setup stage
function Write-PwshProfileStatus {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $Stage,

    [Parameter(Mandatory)]
    [string] $Message,

    [ValidateSet('Info', 'Action', 'Current', 'Success', 'Warning', 'Danger')]
    [string] $Type = 'Info'
  )

  $color = switch ($Type) {
    'Action' { 'Cyan' }
    'Current' { 'Gray' }
    'Success' { 'Green' }
    'Warning' { 'Yellow' }
    'Danger' { 'Red' }
    default { 'Gray' }
  }

  $sectionStages = @('Action', 'Admin', 'Download', 'Install', 'Terminal', 'Winget', 'Complete')
  if ($script:LastPwshProfileStatusStage -and
    $Stage -ne $script:LastPwshProfileStatusStage -and
    $Stage -in $sectionStages) {
    Write-Host ''
  }

  Write-Host ('[{0,-8}] ' -f $Stage) -ForegroundColor DarkGray -NoNewline
  Write-Host $Message -ForegroundColor $color
  $script:LastPwshProfileStatusStage = $Stage
}

function Write-PwshProfileHeader {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $Title,

    [Parameter(Mandatory)]
    [string] $Subtitle
  )

  $line = '═' * 64
  Write-Host ''
  Write-Host $line -ForegroundColor DarkCyan
  Write-Host "  $Title" -ForegroundColor Cyan
  Write-Host "  $Subtitle" -ForegroundColor Gray
  Write-Host $line -ForegroundColor DarkCyan
  Write-Host ''
  $script:LastPwshProfileStatusStage = $null
}

function Test-PwshProfileAdministrator {
  [CmdletBinding()]
  param ()

  if (-not [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
      [System.Runtime.InteropServices.OSPlatform]::Windows
    )) {
    return $false
  }

  $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-WindowsSudoConsoleMode {
  [CmdletBinding()]
  param ()

  $sudo = Get-Command sudo -ErrorAction SilentlyContinue
  if (-not $sudo) {
    return $null
  }

  $configuration = (& $sudo.Source config 2>&1 | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or $configuration -match '(?i)disabled') {
    return $null
  }

  if ($configuration -match '(?i)inline|input\s+closed|disableInput|normal') {
    return [pscustomobject]@{
      Command = $sudo.Source
      Mode    = 'CurrentConsole'
    }
  }

  [pscustomobject]@{
    Command = $sudo.Source
    Mode    = 'NewWindow'
  }
}

function Start-PwshProfileElevated {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $ScriptPath,

    [Parameter(Mandatory)]
    [string] $NerdFontName,

    [switch] $Prerelease,

    [switch] $LocalSource
  )

  if (-not [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
      [System.Runtime.InteropServices.OSPlatform]::Windows
    )) {
    throw 'Administrator elevation for Nerd Font installation is supported only on Windows.'
  }

  $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
  if (-not $pwsh) {
    throw 'PowerShell 7 (pwsh) is required to start the elevated font installation session.'
  }

  $escapedScriptPath = $ScriptPath.Replace("'", "''")
  $escapedFontName = $NerdFontName.Replace("'", "''")
  $command = "& '$escapedScriptPath' -NerdFontName '$escapedFontName' -RunPhase 'NerdFont'"
  if ($Prerelease) {
    $command += ' -Prerelease'
  }
  if ($LocalSource) {
    $command += ' -LocalSource'
  }
  $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
  $arguments = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-EncodedCommand', $encodedCommand
  )

  $sudoConfiguration = Get-WindowsSudoConsoleMode
  if ($sudoConfiguration -and $sudoConfiguration.Mode -eq 'CurrentConsole') {
    Write-PwshProfileStatus -Stage 'Admin' -Type Action -Message 'Approve the UAC prompt; Nerd Font installation will continue in this terminal.'
    & $sudoConfiguration.Command $pwsh.Source @arguments
    if ($LASTEXITCODE -ne 0) {
      throw "The Administrator PowerShell session exited with code $LASTEXITCODE."
    }
    Write-PwshProfileStatus -Stage 'Admin' -Type Success -Message 'Elevated installation completed.'
    return
  }

  Write-PwshProfileStatus -Stage 'Admin' -Type Action -Message 'Approve the UAC prompt; Nerd Font installation will continue in a separate PowerShell window.'
  if (-not $sudoConfiguration) {
    Write-Verbose 'For same-terminal elevation, enable Windows sudo in Inline or Input closed mode.'
  }

  try {
    $process = Start-Process -FilePath $pwsh.Source -Verb RunAs -ArgumentList $arguments -Wait -PassThru -ErrorAction Stop
  } catch {
    throw "Unable to start an Administrator PowerShell session. $($_.Exception.Message)"
  }

  if ($process.ExitCode -ne 0) {
    throw "The Administrator PowerShell session exited with code $($process.ExitCode)."
  }

  Write-PwshProfileStatus -Stage 'Admin' -Type Success -Message 'Elevated installation completed.'
}

function Get-NerdFontsCatalog {
  [CmdletBinding(DefaultParameterSetName = 'Remote')]
  param (
    [Parameter(Mandatory, ParameterSetName = 'Remote')]
    [uri] $RemoteUri,

    [Parameter(Mandatory, ParameterSetName = 'Remote')]
    [ValidatePattern('^[a-fA-F0-9]{64}$')]
    [string] $ExpectedSha256,

    [Parameter(Mandatory, ParameterSetName = 'Local')]
    [string] $LocalPath
  )

  if ($PSCmdlet.ParameterSetName -eq 'Local') {
    Write-PwshProfileStatus -Stage 'Catalog' -Message 'Loading the local Nerd Fonts metadata...'
    Write-Verbose "Catalog source: $LocalPath"
    try {
      $catalogJson = Get-Content -LiteralPath $LocalPath -Raw -ErrorAction Stop
    } catch {
      throw "Unable to load the local Nerd Fonts catalog from '$LocalPath'. $($_.Exception.Message)"
    }
  } else {
    Write-PwshProfileStatus -Stage 'Catalog' -Message 'Loading the latest Nerd Fonts metadata...'
    Write-Verbose "Catalog source: $RemoteUri"

    $catalogTemporaryPath = Join-Path ([System.IO.Path]::GetTempPath()) "NerdFontsCatalog.$PID.json"
    try {
      Save-PwshProfileReleaseAsset -Uri $RemoteUri -Destination $catalogTemporaryPath
      $catalogHash = (Get-FileHash -LiteralPath $catalogTemporaryPath -Algorithm SHA256).Hash.ToLowerInvariant()
      if ($catalogHash -ine $ExpectedSha256) {
        throw 'SHA-256 verification failed for the published Nerd Fonts catalog.'
      }
      $catalogJson = Get-Content -LiteralPath $catalogTemporaryPath -Raw -ErrorAction Stop
    } catch {
      throw "Unable to load the published Nerd Fonts catalog from '$RemoteUri'. $($_.Exception.Message)"
    } finally {
      Remove-Item -LiteralPath $catalogTemporaryPath -Force -ErrorAction SilentlyContinue
    }
  }

  try {
    $catalog = $catalogJson | ConvertFrom-Json -ErrorAction Stop
  } catch {
    throw "The Nerd Fonts catalog is not valid JSON. $($_.Exception.Message)"
  }

  if (-not $catalog.NerdFontsVersion -or @($catalog.Fonts).Count -eq 0) {
    throw 'The Nerd Fonts catalog is missing NerdFontsVersion or font entries.'
  }

  Write-PwshProfileStatus -Stage 'Catalog' -Type Current -Message "Loaded $(@($catalog.Fonts).Count) fonts from release $($catalog.NerdFontsVersion)."

  $catalog
}

function Resolve-NerdFont {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object] $Catalog,

    [Parameter(Mandatory)]
    [string] $Name
  )

  $font = $Catalog.Fonts |
  Where-Object FriendlyName -EQ $Name |
  Select-Object -First 1

  if (-not $font) {
    throw "Nerd Font '$Name' was not found in the generated catalog."
  }

  $font
}

function Get-WindowsFontDirectories {
  [CmdletBinding()]
  param ()

  if (-not [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
      [System.Runtime.InteropServices.OSPlatform]::Windows
    )) {
    throw 'The Windows Fonts directory is available only on Windows.'
  }

  $fontDirectories = @(
    Join-Path $env:WINDIR 'Fonts'
    Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
  ) | Where-Object {
    Test-Path -LiteralPath $_ -PathType Container
  } | Select-Object -Unique

  if (@($fontDirectories).Count -eq 0) {
    throw 'No Windows system or per-user Fonts directories were found.'
  }

  $fontDirectories
}

function ConvertTo-NerdFontMatchName {
  [CmdletBinding()]
  param (
    [AllowEmptyString()]
    [string] $Name
  )

  ($Name -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()
}

function Select-NerdFontMatchingFile {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object] $Font,

    [Parameter(Mandatory, ValueFromPipeline)]
    [System.IO.FileInfo] $File
  )

  begin {
    $matchNames = @(
      @($Font.FriendlyName, $Font.ArchiveName) | ForEach-Object {
        ConvertTo-NerdFontMatchName -Name ([string]$_)
      } | Where-Object { $_.Length -ge 3 } | Sort-Object -Unique
    )
  }

  process {
    $fileName = ConvertTo-NerdFontMatchName -Name $File.BaseName
    $matchesFontName = $matchNames.Where({ $fileName.Contains($_) }).Count -gt 0
    $hasNerdFontMarker = $fileName.Contains('nerdfont') -or
    $matchNames.Where({ $fileName.Contains("${_}nf") }).Count -gt 0

    if ($matchesFontName -and $hasNerdFontMarker) {
      $File
    }
  }
}

function Find-InstalledNerdFont {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object] $Font,

    [Parameter(Mandatory)]
    [string[]] $FontDirectories
  )

  $existingFontDirectories = @(
    $FontDirectories | Where-Object {
      Test-Path -LiteralPath $_ -PathType Container
    } | Select-Object -Unique
  )
  if ($existingFontDirectories.Count -eq 0) {
    throw "No font directories were found: $($FontDirectories -join ', ')"
  }

  Get-ChildItem -LiteralPath $existingFontDirectories -File -ErrorAction Stop |
  Where-Object Extension -In @('.ttf', '.otf', '.ttc') |
  Select-NerdFontMatchingFile -Font $Font |
  Sort-Object FullName -Unique
}

function ConvertTo-NerdFontsReleaseVersion {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $Version
  )

  try {
    [version]($Version.Trim().TrimStart('v'))
  } catch {
    throw "Invalid Nerd Fonts release version '$Version'."
  }
}

function Get-NerdFontInstallDecision {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [bool] $IsInstalled,

    [AllowNull()]
    [object] $InstallState,

    [Parameter(Mandatory)]
    [string] $LatestNerdFontsVersion,

    [Parameter(Mandatory)]
    [string] $LatestFontVersion
  )

  if (-not $IsInstalled) {
    return [pscustomobject]@{
      RequiresInstall    = $true
      InstalledVersion   = $null
      IsNewerThanCatalog = $false
      IsUntracked        = $false
      Reason             = 'not installed'
    }
  }

  if (-not $InstallState -or -not $InstallState.NerdFontsVersion) {
    return [pscustomobject]@{
      RequiresInstall    = $false
      InstalledVersion   = $null
      IsNewerThanCatalog = $false
      IsUntracked        = $true
      Reason             = 'installed release is unknown'
    }
  }

  $installedVersion = [string]$InstallState.NerdFontsVersion
  $installedRelease = ConvertTo-NerdFontsReleaseVersion -Version $installedVersion
  $latestRelease = ConvertTo-NerdFontsReleaseVersion -Version $LatestNerdFontsVersion
  $fontVersionChanged = [string]$InstallState.FontVersion -ne $LatestFontVersion

  if ($installedRelease -gt $latestRelease) {
    return [pscustomobject]@{
      RequiresInstall    = $false
      InstalledVersion   = $installedVersion
      IsNewerThanCatalog = $true
      IsUntracked        = $false
      Reason             = 'installed release is newer than the catalog'
    }
  }

  if ($installedRelease -lt $latestRelease -or $fontVersionChanged) {
    $reason = if ($installedRelease -lt $latestRelease) {
      "Nerd Fonts $installedVersion → $LatestNerdFontsVersion"
    } else {
      "font version $($InstallState.FontVersion) → $LatestFontVersion"
    }

    return [pscustomobject]@{
      RequiresInstall    = $true
      InstalledVersion   = $installedVersion
      IsNewerThanCatalog = $false
      IsUntracked        = $false
      Reason             = $reason
    }
  }

  [pscustomobject]@{
    RequiresInstall    = $false
    InstalledVersion   = $installedVersion
    IsNewerThanCatalog = $false
    IsUntracked        = $false
    Reason             = 'current'
  }
}

function Get-NerdFontInstallState {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $RegistryPath,

    [Parameter(Mandatory)]
    [string] $ArchiveName
  )

  if (-not (Test-Path -LiteralPath $RegistryPath)) {
    return $null
  }

  $registryState = Get-ItemProperty -LiteralPath $RegistryPath -ErrorAction SilentlyContinue
  if (-not $registryState -or -not $registryState.PSObject.Properties[$ArchiveName]) {
    return $null
  }

  $stateJson = $registryState.PSObject.Properties[$ArchiveName].Value
  if (-not $stateJson) {
    return $null
  }

  try {
    $stateJson | ConvertFrom-Json -ErrorAction Stop
  } catch {
    Write-Warning "Ignoring invalid install state for '$ArchiveName'."
    $null
  }
}

function Set-NerdFontInstallState {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $RegistryPath,

    [Parameter(Mandatory)]
    [object] $Font,

    [Parameter(Mandatory)]
    [string] $NerdFontsVersion
  )

  if (-not (Test-Path -LiteralPath $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
  }

  $state = [ordered]@{
    NerdFontsVersion = $NerdFontsVersion
    FontVersion      = [string]$Font.FontVersion
    InstalledAt      = [DateTimeOffset]::UtcNow.ToString('o')
  } | ConvertTo-Json -Compress

  New-ItemProperty -LiteralPath $RegistryPath -Name ([string]$Font.ArchiveName) -Value $state -PropertyType String -Force | Out-Null
}

function Select-NerdFontInstallFiles {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object] $Font,

    [Parameter(Mandatory)]
    [string] $ExtractPath
  )

  $patchedFiles = @(
    Get-ChildItem -LiteralPath $ExtractPath -Recurse -File |
    Where-Object Extension -In @('.ttf', '.otf', '.ttc') |
    Select-NerdFontMatchingFile -Font $Font
  )

  $regularFiles = @($patchedFiles | Where-Object { $_.BaseName -match '(?i)regular' })
  if ($regularFiles.Count -gt 0) {
    $patchedFiles = $regularFiles
  }

  $friendlyName = ConvertTo-NerdFontMatchName -Name ([string]$Font.FriendlyName)
  $preferredFiles = @(
    $patchedFiles | Where-Object {
      (ConvertTo-NerdFontMatchName -Name $_.BaseName) -eq "${friendlyName}nerdfontregular"
    }
  )
  if ($preferredFiles.Count -gt 0) {
    return $preferredFiles
  }

  $patchedFiles | Sort-Object FullName -Unique
}

function Remove-NerdFontRegistration {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [System.IO.FileInfo[]] $FontFiles
  )

  $registryPaths = @(
    'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
  )

  foreach ($registryPath in $registryPaths) {
    if (-not (Test-Path -LiteralPath $registryPath)) {
      continue
    }

    $properties = (Get-ItemProperty -LiteralPath $registryPath).PSObject.Properties
    foreach ($fontFile in $FontFiles) {
      $properties | Where-Object {
        $_.Name -notmatch '^PS' -and
        ([System.IO.Path]::GetFileName([string]$_.Value) -eq $fontFile.Name -or
        [string]$_.Value -eq $fontFile.FullName)
      } | ForEach-Object {
        Remove-ItemProperty -LiteralPath $registryPath -Name $_.Name -ErrorAction SilentlyContinue
      }
    }
  }
}

function Send-WindowsFontChange {
  [CmdletBinding()]
  param ()

  if (-not ('PwshProfile.NativeMethods' -as [type])) {
    Add-Type -TypeDefinition @'
namespace PwshProfile {
  using System;
  using System.Runtime.InteropServices;

  public static class NativeMethods {
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(
      IntPtr hWnd, uint Msg, UIntPtr wParam, IntPtr lParam,
      uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
  }
}
'@
  }

  $result = [UIntPtr]::Zero
  [void][PwshProfile.NativeMethods]::SendMessageTimeout(
    [IntPtr]0xffff,
    0x001D,
    [UIntPtr]::Zero,
    [IntPtr]::Zero,
    0x0002,
    5000,
    [ref]$result
  )
}

function Get-NerdFontFaceName {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [System.IO.FileInfo] $FontFile
  )

  try {
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    $fontCollection = [System.Drawing.Text.PrivateFontCollection]::new()
    try {
      $fontCollection.AddFontFile($FontFile.FullName)
      $familyName = @($fontCollection.Families | Select-Object -ExpandProperty Name) |
      Where-Object { $_ -match '(?i)\b(NF|Nerd Font)\b' } |
      Select-Object -First 1

      if (-not $familyName) {
        $familyName = $fontCollection.Families | Select-Object -ExpandProperty Name -First 1
      }

      if ($familyName) {
        return $familyName
      }
    } finally {
      $fontCollection.Dispose()
    }
  } catch {
    Write-Verbose "Unable to read font family metadata from '$($FontFile.FullName)': $($_.Exception.Message)"
  }

  if ($FontFile.BaseName -match '^(?<family>.+?)NerdFont') {
    return "$($Matches.family) NF"
  }

  $FontFile.BaseName -replace '-Regular$', ''
}

function Get-WindowsTerminalSettingsPaths {
  [CmdletBinding()]
  param ()

  @(
    Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
    Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'
  ) | Where-Object {
    Test-Path -LiteralPath $_ -PathType Leaf
  }
}

function Initialize-CodeDirectory {
  [CmdletBinding()]
  param (
    [string] $CodePath = 'C:\Code',

    [AllowEmptyString()]
    [string] $OneDrivePath = $env:OneDrive
  )

  $existingCodePath = Get-Item -LiteralPath $CodePath -Force -ErrorAction SilentlyContinue
  if ($existingCodePath) {
    if (-not $existingCodePath.PSIsContainer) {
      throw "'$CodePath' exists but is not a directory."
    }

    return $CodePath
  }

  $oneDriveCodePath = if ($OneDrivePath) { Join-Path $OneDrivePath 'Code' }
  if ($oneDriveCodePath -and (Test-Path -LiteralPath $oneDriveCodePath -PathType Container)) {
    try {
      New-Item -ItemType SymbolicLink -Path $CodePath -Target $oneDriveCodePath -ErrorAction Stop | Out-Null
      Write-PwshProfileStatus -Stage 'Terminal' -Type Success -Message "Starting directory linked: $CodePath -> $oneDriveCodePath"
      return $CodePath
    } catch {
      Write-PwshProfileStatus -Stage 'Terminal' -Type Warning -Message "Could not link '$CodePath' to '$oneDriveCodePath'; creating a local directory instead. $($_.Exception.Message)"
    }
  }

  New-Item -ItemType Directory -Path $CodePath -Force -ErrorAction Stop | Out-Null
  Write-PwshProfileStatus -Stage 'Terminal' -Type Success -Message "Starting directory created: $CodePath"
  $CodePath
}

function Set-ObjectPropertyValue {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object] $InputObject,

    [Parameter(Mandatory)]
    [string] $Name,

    [Parameter(Mandatory)]
    [AllowNull()]
    [object] $Value
  )

  if ($InputObject.PSObject.Properties[$Name]) {
    $InputObject.$Name = $Value
  } else {
    Add-Member -InputObject $InputObject -MemberType NoteProperty -Name $Name -Value $Value
  }
}

function Get-WindowsTerminalColorScheme {
  [CmdletBinding()]
  param ()

  [pscustomobject][ordered]@{
    name                = 'Solarized Dark (modified)'
    background          = '#002B36'
    foreground          = '#BDBCBF'
    cursorColor         = '#FFFFFF'
    selectionBackground = '#FFFFFF'
    black               = '#0B5366'
    red                 = '#DC322F'
    green               = '#859900'
    yellow              = '#B58900'
    blue                = '#268BD2'
    purple              = '#D33682'
    cyan                = '#2AA198'
    white               = '#EEE8D5'
    brightBlack         = '#107D99'
    brightRed           = '#CB4B16'
    brightGreen         = '#98C379'
    brightYellow        = '#A6A438'
    brightBlue          = '#839496'
    brightPurple        = '#B4009E'
    brightCyan          = '#D6D6D6'
    brightWhite         = '#FDF6E3'
  }
}

function Set-WindowsTerminalColorScheme {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object] $Settings,

    [Parameter(Mandatory)]
    [object] $ColorScheme
  )

  $schemes = @($Settings.schemes)
  $existingScheme = $schemes |
  Where-Object { $_.name -eq $ColorScheme.name } |
  Select-Object -First 1

  if (-not $existingScheme) {
    Set-ObjectPropertyValue -InputObject $Settings -Name 'schemes' -Value @($schemes + $ColorScheme)
    return $true
  }

  $changed = $false
  foreach ($property in $ColorScheme.PSObject.Properties) {
    if (-not $existingScheme.PSObject.Properties[$property.Name] -or
      $existingScheme.($property.Name) -ne $property.Value) {
      Set-ObjectPropertyValue -InputObject $existingScheme -Name $property.Name -Value $property.Value
      $changed = $true
    }
  }
  $changed
}

function Set-WindowsTerminalProfileOrder {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [object[]] $Profiles
  )

  $profileDefinitions = @(
    [pscustomobject]@{
      Role          = 'Pwsh7'
      Name          = 'Pwsh 7'
      PreferredGuid = '574e775e-4f2a-5b96-ac1e-a2962a402336'
    }
    [pscustomobject]@{
      Role          = 'Pwsh5'
      Name          = 'Pwsh 5'
      PreferredGuid = '61c54bbd-c2c6-5271-96e7-009a87ff44bf'
    }
    [pscustomobject]@{
      Role          = 'CommandPrompt'
      Name          = 'Command Prompt'
      PreferredGuid = '0caa0dad-35be-5f56-a8ff-afceeeaa6101'
    }
    [pscustomobject]@{
      Role          = 'AzureCloudShell'
      Name          = 'Azure Cloud Shell'
      PreferredGuid = 'b453ae62-4e3d-5e58-b989-0a998ec441b8'
    }
  )
  $selectedIndexes = [System.Collections.Generic.HashSet[int]]::new()
  $orderedProfiles = [System.Collections.Generic.List[object]]::new()
  $guidReplacements = @{}
  $removedCount = 0
  $changed = $false

  foreach ($definition in $profileDefinitions) {
    $matchingIndexes = [System.Collections.Generic.List[int]]::new()
    for ($index = 0; $index -lt $Profiles.Count; $index++) {
      $profile = $Profiles[$index]
      $guid = ([string]$profile.guid).Trim('{}')
      $role = if ($guid -ieq '574e775e-4f2a-5b96-ac1e-a2962a402336' -or
        [string]$profile.source -eq 'Windows.Terminal.PowershellCore') {
        'Pwsh7'
      } elseif ($guid -ieq '61c54bbd-c2c6-5271-96e7-009a87ff44bf') {
        'Pwsh5'
      } elseif ($guid -ieq '0caa0dad-35be-5f56-a8ff-afceeeaa6101') {
        'CommandPrompt'
      } elseif ([string]$profile.source -eq 'Windows.Terminal.Azure') {
        'AzureCloudShell'
      }

      if ($role -eq $definition.Role) {
        $matchingIndexes.Add($index)
      }
    }

    if ($matchingIndexes.Count -eq 0) {
      continue
    }

    $selectedIndex = @($matchingIndexes | Where-Object {
        ([string]$Profiles[$_].guid).Trim('{}') -ieq $definition.PreferredGuid
      } | Select-Object -First 1)
    if ($selectedIndex.Count -eq 0) {
      $selectedIndex = $matchingIndexes[0]
    } else {
      $selectedIndex = $selectedIndex[0]
    }

    $profile = $Profiles[$selectedIndex]
    $selectedGuid = ([string]$profile.guid).Trim('{}')
    if ($profile.name -ne $definition.Name) {
      Set-ObjectPropertyValue -InputObject $profile -Name 'name' -Value $definition.Name
      $changed = $true
    }
    if ($selectedIndex -ne $orderedProfiles.Count) {
      $changed = $true
    }

    $orderedProfiles.Add($profile)
    foreach ($matchingIndex in $matchingIndexes) {
      [void]$selectedIndexes.Add($matchingIndex)
      if ($matchingIndex -eq $selectedIndex) {
        continue
      }

      $removedGuid = ([string]$Profiles[$matchingIndex].guid).Trim('{}')
      if ($removedGuid -and $selectedGuid) {
        $guidReplacements[$removedGuid.ToLowerInvariant()] = $selectedGuid
      }
      $removedCount++
      $changed = $true
    }
  }

  for ($index = 0; $index -lt $Profiles.Count; $index++) {
    if (-not $selectedIndexes.Contains($index)) {
      $orderedProfiles.Add($Profiles[$index])
    }
  }

  [pscustomobject]@{
    Profiles         = $orderedProfiles.ToArray()
    Changed          = $changed
    RemovedCount     = $removedCount
    GuidReplacements = $guidReplacements
  }
}

function Update-WindowsTerminalProfileGuidReferences {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object] $Settings,

    [Parameter(Mandatory)]
    [System.Collections.IDictionary] $GuidReplacements
  )

  $replacementState = @{ Count = 0 }
  $updateNode = {
    param([AllowNull()][object] $Node)

    if ($null -eq $Node -or $Node -is [string] -or $Node -is [ValueType]) {
      return
    }

    if ($Node -is [System.Collections.IDictionary]) {
      foreach ($key in @($Node.Keys)) {
        $value = $Node[$key]
        if ($value -is [string]) {
          $normalizedGuid = $value.Trim('{}').ToLowerInvariant()
          if ($GuidReplacements.Contains($normalizedGuid)) {
            $Node[$key] = "{$($GuidReplacements[$normalizedGuid])}"
            $replacementState.Count++
          }
        } else {
          & $updateNode $value
        }
      }
      return
    }

    if ($Node -is [System.Collections.IList]) {
      for ($index = 0; $index -lt $Node.Count; $index++) {
        $value = $Node[$index]
        if ($value -is [string]) {
          $normalizedGuid = $value.Trim('{}').ToLowerInvariant()
          if ($GuidReplacements.Contains($normalizedGuid)) {
            $Node[$index] = "{$($GuidReplacements[$normalizedGuid])}"
            $replacementState.Count++
          }
        } else {
          & $updateNode $value
        }
      }
      return
    }

    foreach ($property in @($Node.PSObject.Properties | Where-Object { $_.IsSettable })) {
      $value = $property.Value
      if ($value -is [string]) {
        $normalizedGuid = $value.Trim('{}').ToLowerInvariant()
        if ($GuidReplacements.Contains($normalizedGuid)) {
          $property.Value = "{$($GuidReplacements[$normalizedGuid])}"
          $replacementState.Count++
        }
      } else {
        & $updateNode $value
      }
    }
  }

  & $updateNode $Settings
  $replacementState.Count
}

function Update-WindowsTerminalFontFace {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $FontFace,

    [int] $FontSize = 9,

    [string] $StartingDirectory = 'C:\Code',

    [switch] $PostInstall,

    [object] $ColorScheme = (Get-WindowsTerminalColorScheme),

    [string[]] $SettingsPaths = @(Get-WindowsTerminalSettingsPaths)
  )

  if ($SettingsPaths.Count -eq 0) {
    Write-PwshProfileStatus -Stage 'Terminal' -Type Warning -Message 'Windows Terminal settings were not found; font update skipped.'
    return
  }

  foreach ($settingsPath in $SettingsPaths) {
    $settingsJson = Get-Content -LiteralPath $settingsPath -Raw -ErrorAction Stop
    try {
      $settings = $settingsJson | ConvertFrom-Json -ErrorAction Stop
    } catch {
      Write-PwshProfileStatus -Stage 'Terminal' -Type Warning -Message "Could not parse settings at $settingsPath; font update skipped."
      continue
    }

    $changed = $false
    if (-not $settings.profiles) {
      Set-ObjectPropertyValue -InputObject $settings -Name 'profiles' -Value ([pscustomobject]@{})
      $changed = $true
    }
    if (-not $settings.profiles.defaults) {
      Set-ObjectPropertyValue -InputObject $settings.profiles -Name 'defaults' -Value ([pscustomobject]@{})
      $changed = $true
    }
    if ($settings.profiles.defaults.startingDirectory -ne $StartingDirectory) {
      Set-ObjectPropertyValue -InputObject $settings.profiles.defaults -Name 'startingDirectory' -Value $StartingDirectory
      $changed = $true
    }
    if ($settings.profiles.defaults.colorScheme -ne $ColorScheme.name) {
      Set-ObjectPropertyValue -InputObject $settings.profiles.defaults -Name 'colorScheme' -Value $ColorScheme.name
      $changed = $true
    }
    if (Set-WindowsTerminalColorScheme -Settings $settings -ColorScheme $ColorScheme) {
      $changed = $true
    }
    if (-not $settings.profiles.defaults.font) {
      Set-ObjectPropertyValue -InputObject $settings.profiles.defaults -Name 'font' -Value ([pscustomobject]@{})
      $changed = $true
    }
    if ($settings.profiles.defaults.font.face -ne $FontFace) {
      Set-ObjectPropertyValue -InputObject $settings.profiles.defaults.font -Name 'face' -Value $FontFace
      $changed = $true
    }
    if ($settings.profiles.defaults.font.size -ne $FontSize) {
      Set-ObjectPropertyValue -InputObject $settings.profiles.defaults.font -Name 'size' -Value $FontSize
      $changed = $true
    }

    $removedProfileCount = 0
    if ($settings.profiles.list) {
      $profileOrder = Set-WindowsTerminalProfileOrder -Profiles @($settings.profiles.list)
      $removedProfileCount = $profileOrder.RemovedCount
      if ($profileOrder.Changed) {
        $settings.profiles.list = $profileOrder.Profiles
        $changed = $true
      }
      if ($profileOrder.GuidReplacements.Count -gt 0 -and
        (Update-WindowsTerminalProfileGuidReferences `
          -Settings $settings `
          -GuidReplacements $profileOrder.GuidReplacements) -gt 0) {
        $changed = $true
      }

      foreach ($terminalProfile in @($settings.profiles.list)) {
        if ($terminalProfile.font -and $terminalProfile.font.face -and $terminalProfile.font.face -ne $FontFace) {
          $terminalProfile.font.face = $FontFace
          $changed = $true
        }
        if ($terminalProfile.font -and $terminalProfile.font.size -and $terminalProfile.font.size -ne $FontSize) {
          $terminalProfile.font.size = $FontSize
          $changed = $true
        }
      }
    }

    if (-not $changed) {
      $statusSuffix = if ($PostInstall) { 'confirmed' } else { 'already configured' }
      $statusType = if ($PostInstall) { 'Success' } else { 'Current' }
      Write-PwshProfileStatus -Stage 'Terminal' -Type $statusType -Message "Font Face: $FontFace $statusSuffix"
      Write-PwshProfileStatus -Stage 'Terminal' -Type $statusType -Message "Font Size: $FontSize $statusSuffix"
      Write-PwshProfileStatus -Stage 'Terminal' -Type $statusType -Message "Color Scheme: $($ColorScheme.name) $statusSuffix"
      Write-PwshProfileStatus -Stage 'Terminal' -Type $statusType -Message "Starting Directory: $StartingDirectory $statusSuffix"
      Write-PwshProfileStatus -Stage 'Terminal' -Type $statusType -Message "Profiles: Pwsh 7, Pwsh 5, Command Prompt, Azure Cloud Shell; no duplicates; order $statusSuffix"
      continue
    }

    $backupTimestamp = [DateTimeOffset]::UtcNow.ToString('yyyyMMddHHmmss')
    $backupPath = "$settingsPath.$backupTimestamp.bak"
    Copy-Item -LiteralPath $settingsPath -Destination $backupPath -Force
    $updatedJson = $settings | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText(
      [System.IO.Path]::GetFullPath($settingsPath),
      "$updatedJson`n",
      [System.Text.UTF8Encoding]::new($false)
    )
    Write-PwshProfileStatus -Stage 'Terminal' -Type Success -Message "Font Face: $FontFace"
    Write-PwshProfileStatus -Stage 'Terminal' -Type Success -Message "Font Size: $FontSize"
    Write-PwshProfileStatus -Stage 'Terminal' -Type Success -Message "Color Scheme: $($ColorScheme.name)"
    Write-PwshProfileStatus -Stage 'Terminal' -Type Success -Message "Starting Directory: $StartingDirectory"
    Write-PwshProfileStatus -Stage 'Terminal' -Type Success -Message "Profiles: Pwsh 7, Pwsh 5, Command Prompt, Azure Cloud Shell; removed $removedProfileCount duplicate(s); order enforced"
    Write-PwshProfileStatus -Stage 'Terminal' -Type Success -Message "Config Backup: $backupPath"
  }
}

function Update-WindowsTerminalFromNerdFontFiles {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [System.IO.FileInfo[]] $FontFiles,

    [switch] $PostInstall,

    [string[]] $SettingsPaths = @(Get-WindowsTerminalSettingsPaths)
  )

  try {
    $startingDirectory = Initialize-CodeDirectory
  } catch {
    Write-PwshProfileStatus -Stage 'Terminal' -Type Warning -Message "Could not prepare the starting directory: $($_.Exception.Message)"
    return
  }

  if ($FontFiles.Count -eq 0) {
    Write-PwshProfileStatus -Stage 'Terminal' -Type Warning -Message 'No installed font files were found; settings update skipped.'
    return
  }

  $fontFace = Get-NerdFontFaceName -FontFile $FontFiles[0]
  Update-WindowsTerminalFontFace -FontFace $fontFace -StartingDirectory $startingDirectory -PostInstall:$PostInstall -SettingsPaths $SettingsPaths
  Write-Host ''
  Write-PwshProfileStatus -Stage 'VS Code' -Message "Recommended terminal.integrated.fontFamily: '$fontFace', Consolas, 'Courier New', monospace"
  Write-PwshProfileStatus -Stage 'VS Code' -Message "Recommended editor.fontFamily: '$fontFace', Consolas, 'Courier New', monospace"
}

function Install-NerdFont {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object] $Font,

    [Parameter(Mandatory)]
    [string] $NerdFontsVersion,

    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [System.IO.FileInfo[]] $ExistingFiles,

    [Parameter(Mandatory)]
    [string] $StateRegistryPath
  )

  if (-not (Test-PwshProfileAdministrator)) {
    throw 'Nerd Font installation must run in an Administrator PowerShell session.'
  }

  $tempRoot = Join-Path $env:TEMP "NerdFont-$($Font.ArchiveName)-$([guid]::NewGuid().ToString('N'))"
  $archivePath = "$tempRoot.zip"
  New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

  try {
    Write-PwshProfileStatus -Stage 'Download' -Type Action -Message "$($Font.FriendlyName) from Nerd Fonts $NerdFontsVersion"
    Invoke-WebRequest -Uri $Font.DownloadUrl -OutFile $archivePath -UseBasicParsing -ErrorAction Stop
    Expand-Archive -LiteralPath $archivePath -DestinationPath $tempRoot -Force

    $installFiles = @(Select-NerdFontInstallFiles -Font $Font -ExtractPath $tempRoot)
    if ($installFiles.Count -eq 0) {
      throw "No installable Nerd Font files were found in '$($Font.DownloadUrl)'."
    }

    if ($ExistingFiles.Count -gt 0) {
      Remove-NerdFontRegistration -FontFiles $ExistingFiles
      foreach ($existingFile in $ExistingFiles) {
        Remove-Item -LiteralPath $existingFile.FullName -Force -ErrorAction Stop
      }
    }

    $systemFontDirectory = Join-Path $env:WINDIR 'Fonts'
    $systemFontRegistry = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    $installedFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    foreach ($fontFile in $installFiles) {
      $destination = Join-Path $systemFontDirectory $fontFile.Name
      Copy-Item -LiteralPath $fontFile.FullName -Destination $destination -Force -ErrorAction Stop
      $fontType = if ($fontFile.Extension -ieq '.otf') { 'OpenType' } else { 'TrueType' }
      $registryName = "$($fontFile.BaseName) ($fontType)"
      New-ItemProperty -LiteralPath $systemFontRegistry -Name $registryName -Value $fontFile.Name -PropertyType String -Force | Out-Null
      Write-PwshProfileStatus -Stage 'Install' -Type Success -Message $destination
      $installedFiles.Add((Get-Item -LiteralPath $destination))
    }

    Send-WindowsFontChange
    Set-NerdFontInstallState -RegistryPath $StateRegistryPath -Font $Font -NerdFontsVersion $NerdFontsVersion
    $installedFiles
  } finally {
    Remove-Item -LiteralPath $archivePath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Get-WingetPackageDefinitions {
  [CmdletBinding()]
  param ()

  @(
    # System - Machine Scoped Applications
    [pscustomobject]@{ Id = 'Amazon.AWSCLI'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'FireDaemon.OpenSSL'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'Git.Git'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'GitHub.cli'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'GitHub.Copilot'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'Hashicorp.Terraform'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'Helm.Helm'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'jqlang.jq'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'Kubernetes.kubectl'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'Microsoft.AzureCLI'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'Microsoft.Azure.Kubelogin'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'Microsoft.PowerShell'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'MikeFarah.yq'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'Ookla.Speedtest.CLI'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'OpenAI.Codex'; Scope = 'machine' }

    # Use Scoped Applications
    [pscustomobject]@{ Id = 'JanDeDobbeleer.OhMyPosh'; Scope = 'user' }
    [pscustomobject]@{ Id = 'Microsoft.Bicep'; Scope = 'user' }
  )
}

function Get-WingetCommand {
  [CmdletBinding()]
  param ()

  $winget = Get-Command winget -ErrorAction SilentlyContinue
  if (-not $winget) {
    throw 'Winget was not found. Install App Installer from Microsoft Store, then rerun this script.'
  }

  $winget.Source
}

function Get-LatestWingetRelease {
  [CmdletBinding()]
  param ()

  Invoke-RestMethod -Uri 'https://api.github.com/repos/microsoft/winget-cli/releases/latest' -ErrorAction Stop
}

function Update-WingetClient {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $WingetPath
  )

  try {
    $currentVersionText = (& $WingetPath --version 2>$null | Select-Object -First 1)
    if (-not $currentVersionText) {
      Write-PwshProfileStatus -Stage 'Winget' -Type Warning -Message 'Could not determine the installed winget version; skipping self-update.'
      return
    }
    $currentVersion = [version]($currentVersionText.Trim().TrimStart('v'))

    $release = Invoke-WithRetry -Stage 'Winget' -Description 'Check latest winget release' -ScriptBlock {
      Get-LatestWingetRelease
    }
    $latestVersion = [version]($release.tag_name.TrimStart('v'))

    if ($currentVersion -ge $latestVersion) {
      Write-PwshProfileStatus -Stage 'Winget' -Type Current -Message "Version: $currentVersion [latest]"
      return
    }

    Write-PwshProfileStatus -Stage 'Winget' -Type Action -Message "Version: $currentVersion, updating to $latestVersion..."

    $bundleAsset = $release.assets | Where-Object { $_.name -like '*.msixbundle' } | Select-Object -First 1
    if (-not $bundleAsset) {
      Write-PwshProfileStatus -Stage 'Winget' -Type Warning -Message 'Latest winget release has no msixbundle asset; skipping self-update.'
      return
    }

    $tempRoot = Join-Path $env:TEMP "winget-update-$([guid]::NewGuid())"
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    try {
      $bundlePath = Join-Path $tempRoot $bundleAsset.name
      Invoke-WithRetry -Stage 'Winget' -Description 'Download winget package' -ScriptBlock {
        Invoke-WebRequest -Uri $bundleAsset.browser_download_url -OutFile $bundlePath -UseBasicParsing -ErrorAction Stop
      }

      Add-AppxPackage -Path $bundlePath -ForceApplicationShutdown -ErrorAction Stop
      Write-PwshProfileStatus -Stage 'Winget' -Type Success -Message "winget updated to $latestVersion."
    } finally {
      Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  } catch {
    Write-PwshProfileStatus -Stage 'Winget' -Type Warning -Message "winget self-update failed: $($_.Exception.Message)"
  }
}

function Update-WingetSources {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $WingetPath
  )

  Write-Host ''
  Write-PwshProfileStatus -Stage 'Winget' -Type Action -Message 'Updating sources...'
  $sourceUpdateOutput = & $WingetPath source update --disable-interactivity 2>&1
  $sourceUpdateExitCode = $LASTEXITCODE
  $sourceUpdateOutput | ForEach-Object {
    $line = ([string]$_).Trim()
    if ($line) {
      Write-PwshProfileStatus -Stage 'Winget' -Message $line
    }
  }

  if ($sourceUpdateExitCode -ne 0) {
    throw "Winget source update failed with exit code $sourceUpdateExitCode."
  }

  Write-PwshProfileStatus -Stage 'Winget' -Type Success -Message 'Sources updated.'
  Write-Host ''
}

function ConvertFrom-WingetTableRow {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string[]] $Lines,

    [Parameter(Mandatory)]
    [string] $PackageId
  )

  $headerIndex = -1
  for ($i = 0; $i -lt $Lines.Count; $i++) {
    if ($Lines[$i] -match '^\s*Name\s+Id\s+Version') {
      $headerIndex = $i
      break
    }
  }
  if ($headerIndex -lt 0 -or $headerIndex + 2 -ge $Lines.Count) {
    return $null
  }

  $header = $Lines[$headerIndex]
  $columnStarts = [ordered]@{}
  foreach ($column in @('Name', 'Id', 'Version', 'Available', 'Source')) {
    $match = [regex]::Match($header, "\b$column\b")
    if ($match.Success) {
      $columnStarts[$column] = $match.Index
    }
  }

  $dataRow = $Lines[($headerIndex + 2)..($Lines.Count - 1)] | Where-Object { $_ -match [regex]::Escape($PackageId) } | Select-Object -First 1
  if (-not $dataRow) {
    return $null
  }

  $columns = @($columnStarts.Keys)
  $result = [ordered]@{}
  for ($i = 0; $i -lt $columns.Count; $i++) {
    $start = $columnStarts[$columns[$i]]
    if ($start -ge $dataRow.Length) {
      continue
    }
    $end = if ($i -lt $columns.Count - 1) { $columnStarts[$columns[$i + 1]] } else { $dataRow.Length }
    $length = [Math]::Min($end, $dataRow.Length) - $start
    $result[$columns[$i]] = $dataRow.Substring($start, $length).Trim()
  }

  [pscustomobject]$result
}

function Get-WingetPackageVersionInfo {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $PackageId,

    [Parameter(Mandatory)]
    [string] $WingetPath
  )

  try {
    # `winget upgrade --id ...` performs the upgrade; it is not a read-only query.
    # `winget list` includes an Available column when an upgrade exists.
    $output = & $WingetPath list --id $PackageId --exact --source winget --accept-source-agreements --disable-interactivity 2>$null
    # Only WinGet's documented no-applications HRESULT means absent.
    if ($LASTEXITCODE -eq -1978335212) { return $null }
    if ($LASTEXITCODE -ne 0) { throw "Winget query failed with exit code $LASTEXITCODE." }

    # Winget emits ANSI colour codes even when output is redirected; strip them before column parsing.
    $ansiEscapePattern = '{0}\[[0-9;]*[a-zA-Z]' -f [char]27
    $plainLines = $output | ForEach-Object { $_ -replace $ansiEscapePattern, '' }
    $info = ConvertFrom-WingetTableRow -Lines $plainLines -PackageId $PackageId
    if (-not $info -or $info.Id -ne $PackageId -or -not $info.Version) {
      throw 'Winget output could not be interpreted; package state is unknown (possibly localized output).'
    }
    $info
  } catch {
    throw "Could not query '$PackageId': $($_.Exception.Message)"
  }
}

function Invoke-WingetElevatedPackageAction {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $WingetPath,

    [Parameter(Mandatory)]
    [string[]] $Arguments,

    [Parameter(Mandatory)]
    [string] $PackageId
  )

  $sudoConfiguration = Get-WindowsSudoConsoleMode
  if ($sudoConfiguration -and $sudoConfiguration.Mode -eq 'CurrentConsole') {
    & $sudoConfiguration.Command $WingetPath @Arguments
    if ($LASTEXITCODE -ne 0) {
      throw "Elevated Winget command failed for '$PackageId' with exit code $LASTEXITCODE."
    }
    return
  }

  Write-PwshProfileStatus -Stage 'Admin' -Type Action -Message "Approve the UAC prompt; only '$PackageId' will run elevated."
  $process = Start-Process -FilePath $WingetPath -Verb RunAs -ArgumentList $Arguments -Wait -PassThru -ErrorAction Stop
  if ($process.ExitCode -ne 0) {
    throw "Elevated Winget command failed for '$PackageId' with exit code $($process.ExitCode)."
  }
}

function Get-WingetScopeDisplayName {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [ValidateSet('machine', 'user')]
    [string] $Scope
  )

  if ($Scope -eq 'machine') { 'Machine' } else { 'User' }
}

function Invoke-WingetPackageAction {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object] $Package,

    [Parameter(Mandatory)]
    [string] $WingetPath,

    [Parameter(Mandatory)]
    [ValidateSet('install', 'upgrade')]
    [string] $Action
  )

  $arguments = @(
    $Action,
    '--id', $Package.Id,
    '--exact',
    '--source', 'winget',
    '--scope', $Package.Scope,
    '--silent',
    '--accept-package-agreements',
    '--accept-source-agreements',
    '--disable-interactivity'
  )

  Write-Host ''
  $displayAction = if ($Action -eq 'install') { 'Installing' } else { 'Upgrading' }
  $displayScope = Get-WingetScopeDisplayName -Scope $Package.Scope
  Write-PwshProfileStatus -Stage 'Winget' -Type Action -Message "$displayAction $($Package.Id) [$displayScope]"
  if ($Package.Scope -eq 'machine' -and -not (Test-PwshProfileAdministrator)) {
    Invoke-WingetElevatedPackageAction -WingetPath $WingetPath -Arguments $arguments -PackageId $Package.Id
    return
  }

  & $WingetPath @arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Winget $Action failed for '$($Package.Id)' with exit code $LASTEXITCODE."
  }
}

function Show-WingetPackageInventory {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object[]] $Packages
  )

  $Packages |
  Format-Table -Property `
  @{ Label = 'Package ID'; Expression = { $_.Id } },
  @{ Label = 'Scope'; Expression = { Get-WingetScopeDisplayName -Scope $_.Scope } } `
    -AutoSize |
  Out-String -Width 160 |
  ForEach-Object {
    $_ -split '\r?\n'
  } |
  ForEach-Object {
    $_.TrimEnd()
  } |
  Where-Object { $_ } |
  ForEach-Object {
    Write-PwshProfileStatus -Stage 'Winget' -Message $_
  }
  Write-Host ''
}

function Invoke-WingetConfiguration {
  [CmdletBinding()]
  param ()

  Write-PwshProfileHeader -Title 'Pwsh Profile Installer' -Subtitle 'Winget Package Configuration'

  $wingetPath = Get-WingetCommand
  Update-WingetClient -WingetPath $wingetPath
  $wingetPath = Get-WingetCommand
  Update-WingetSources -WingetPath $wingetPath

  $packages = @(Get-WingetPackageDefinitions | Sort-Object Scope, Id)
  Show-WingetPackageInventory -Packages $packages
  Write-PwshProfileStatus -Stage 'Winget' -Message "Checking $($packages.Count) package(s)..."

  $packageStates = @(
    foreach ($package in $packages) {
      Write-PwshProfileStatus -Stage 'Check' -Message $package.Id
      $queryError = $null
      $installedInfo = $null
      try { $installedInfo = Get-WingetPackageVersionInfo -PackageId $package.Id -WingetPath $wingetPath }
      catch { $queryError = $_.Exception.Message }
      [pscustomobject]@{
        Package       = $package
        InstalledInfo = $installedInfo
        QueryError    = $queryError
      }
    }
  )

  $summary = [ordered]@{
    Updated = 0
    Current = 0
    Failed  = 0
  }

  foreach ($state in $packageStates) {
    $displayScope = Get-WingetScopeDisplayName -Scope $state.Package.Scope
    try {
      if ($state.QueryError) { throw $state.QueryError }
      if ($state.InstalledInfo) {
        $installedVersion = if ($state.InstalledInfo.Version) { $state.InstalledInfo.Version } else { 'unknown version' }
        if ($state.InstalledInfo.Available) {
          $latestVersion = $state.InstalledInfo.Available
          Write-PwshProfileStatus -Stage 'Winget' -Type Action -Message "$($state.Package.Id) installed $installedVersion, updating to $latestVersion [$displayScope]"
          Invoke-WingetPackageAction -Package $state.Package -WingetPath $wingetPath -Action upgrade
          $summary.Updated++
        } else {
          Write-PwshProfileStatus -Stage 'Winget' -Type Current -Message "$($state.Package.Id) installed $installedVersion [latest] [$displayScope]"
          $summary.Current++
        }
      } else {
        Invoke-WingetPackageAction -Package $state.Package -WingetPath $wingetPath -Action install
        $summary.Updated++
      }
    } catch {
      Write-PwshProfileStatus -Stage 'Winget' -Type Warning -Message "$($state.Package.Id) failed: $($_.Exception.Message)"
      $summary.Failed++
    }
  }

  Write-Host ''
  $summaryType = if ($summary.Failed -gt 0) { 'Warning' } elseif ($summary.Updated -gt 0) { 'Success' } else { 'Current' }
  Write-PwshProfileStatus -Stage 'Winget' -Type $summaryType -Message "Summary: $($summary.Updated) updated, $($summary.Current) current, $($summary.Failed) failed."
}

function Get-PowerShellModuleDefinitions {
  [CmdletBinding()]
  param ()

  @(
    [pscustomobject]@{ Name = 'PackageManagement'; Scope = 'CurrentUser' }
    [pscustomobject]@{ Name = 'PowerShellGet'; Scope = 'CurrentUser' }
    [pscustomobject]@{ Name = 'Az'; Scope = 'CurrentUser' }
    [pscustomobject]@{ Name = 'Microsoft.Graph'; Scope = 'CurrentUser' }
    [pscustomobject]@{ Name = 'Pester'; Scope = 'CurrentUser' }
    [pscustomobject]@{ Name = 'PSReadLine'; Scope = 'CurrentUser' }
    [pscustomobject]@{ Name = 'PSRule'; Scope = 'CurrentUser' }
    [pscustomobject]@{ Name = 'PSRule.Rules.Azure'; Scope = 'CurrentUser' }
    [pscustomobject]@{ Name = 'Terminal-Icons'; Scope = 'CurrentUser' }
  )
}

function Initialize-PowerShellGallery {
  [CmdletBinding()]
  param ()

  if (-not (Get-Command Install-Module -ErrorAction SilentlyContinue)) {
    throw 'Install-Module was not found. Install PowerShellGet, then rerun this script.'
  }

  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

  Write-PwshProfileStatus -Stage 'Modules' -Message 'Checking NuGet package provider...'
  $nugetProvider = Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue |
  Sort-Object Version -Descending |
  Select-Object -First 1

  if (-not $nugetProvider -or $nugetProvider.Version -lt [version]'2.8.5.201') {
    Write-PwshProfileStatus -Stage 'Modules' -Type Action -Message 'Installing NuGet package provider 2.8.5.201...'
    Invoke-WithRetry -Description 'Install NuGet provider' -ScriptBlock {
      Install-PackageProvider -Name NuGet -MinimumVersion '2.8.5.201' -Force -Scope CurrentUser -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
    }
    Write-PwshProfileStatus -Stage 'Modules' -Type Success -Message 'NuGet package provider installed.'
  } else {
    Write-PwshProfileStatus -Stage 'Modules' -Type Current -Message "NuGet package provider $($nugetProvider.Version)."
  }

  Import-PackageProvider -Name NuGet -Force -ErrorAction Stop | Out-Null

  $repository = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
  if (-not $repository) {
    throw 'PSGallery repository was not found. Register PSGallery, then rerun this script.'
  }

  if ($repository.InstallationPolicy -ne 'Trusted') {
    Write-PwshProfileStatus -Stage 'Modules' -Type Action -Message 'Trusting PSGallery repository...'
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -WarningAction SilentlyContinue
    Write-PwshProfileStatus -Stage 'Modules' -Type Success -Message 'PSGallery trusted.'
  } else {
    Write-PwshProfileStatus -Stage 'Modules' -Type Current -Message 'PSGallery already trusted.'
  }
}

function Invoke-WithRetry {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [scriptblock] $ScriptBlock,

    [Parameter(Mandatory)]
    [string] $Description,

    [ValidateSet('Modules', 'Winget')]
    [string] $Stage = 'Modules',

    [int] $MaxAttempts = 3,

    [int] $DelaySeconds = 5
  )

  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    try {
      return & $ScriptBlock
    } catch {
      if ($attempt -eq $MaxAttempts) {
        throw "'$Description' failed after $MaxAttempts attempts. $($_.Exception.Message)"
      }
      Write-PwshProfileStatus -Stage $Stage -Type Warning -Message "$Description failed ($attempt/$MaxAttempts); retrying in ${DelaySeconds}s..."
      Start-Sleep -Seconds $DelaySeconds
    }
  }
}

function Get-PowerShellModuleRoot {
  [CmdletBinding()]
  param ()

  $documentsPath = [Environment]::GetFolderPath('MyDocuments')
  $subfolder = if ($PSVersionTable.PSEdition -eq 'Core') { 'PowerShell' } else { 'WindowsPowerShell' }
  Join-Path $documentsPath "$subfolder\Modules"
}

function Get-InstalledPowerShellModules {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $Name
  )

  $moduleRoot = Join-Path (Get-PowerShellModuleRoot) $Name
  if (-not (Test-Path -LiteralPath $moduleRoot)) {
    return
  }

  Get-ChildItem -LiteralPath $moduleRoot -Directory -ErrorAction SilentlyContinue |
  ForEach-Object {
    $version = $null
    if ([version]::TryParse($_.Name, [ref] $version)) {
      [pscustomobject]@{
        Name       = $Name
        Version    = $version
        ModuleBase = $_.FullName
      }
    }
  } |
  Sort-Object Version -Descending
}

function Remove-OldPowerShellModuleVersions {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $Name
  )

  $oldModules = @(Get-InstalledPowerShellModules -Name $Name | Select-Object -Skip 1)
  foreach ($oldModule in $oldModules) {
    try {
      Write-PwshProfileStatus -Stage 'Modules' -Type Action -Message "Removing $Name $($oldModule.Version)"
      Remove-Module -FullyQualifiedName @{ ModuleName = $Name; ModuleVersion = $oldModule.Version } -Force -ErrorAction SilentlyContinue
      Remove-Item -LiteralPath $oldModule.ModuleBase -Recurse -Force -ErrorAction Stop
      Write-PwshProfileStatus -Stage 'Modules' -Type Success -Message "Removed $Name $($oldModule.Version)."
    } catch {
      Write-PwshProfileStatus -Stage 'Modules' -Type Warning -Message "Could not remove $Name $($oldModule.Version); it may be in use."
    }
  }
}

function Get-PowerShellModuleInstallState {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $RegistryPath,

    [Parameter(Mandatory)]
    [string] $Name
  )

  if (-not (Test-Path -LiteralPath $RegistryPath)) {
    return $null
  }

  $registryState = Get-ItemProperty -LiteralPath $RegistryPath -ErrorAction SilentlyContinue
  if (-not $registryState -or -not $registryState.PSObject.Properties[$Name]) {
    return $null
  }

  try {
    [version]$registryState.PSObject.Properties[$Name].Value
  } catch {
    $null
  }
}

function Set-PowerShellModuleInstallState {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $RegistryPath,

    [Parameter(Mandatory)]
    [string] $Name,

    [Parameter(Mandatory)]
    [version] $Version
  )

  if (-not (Test-Path -LiteralPath $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
  }

  New-ItemProperty -LiteralPath $RegistryPath -Name $Name -Value $Version.ToString() -PropertyType String -Force | Out-Null
}

function Invoke-PowerShellModuleAction {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object] $Module,

    [Parameter(Mandatory)]
    [string] $StateRegistryPath
  )

  try {
    # PackageManagement/PowerShellGet/PSReadLine are bootstrap modules PowerShellGet handles
    # specially, and can end up saved somewhere our disk scan never finds even with an explicit
    # -Path. Track our own record of the last version we successfully saved (like the Nerd Font
    # registry state) so detection doesn't depend solely on locating the files afterward.
    $isBootstrapModule = $Module.Name -in @('PackageManagement', 'PowerShellGet', 'PSReadLine')
    $diskModule = Get-InstalledPowerShellModules -Name $Module.Name | Select-Object -First 1
    $trackedVersion = if ($isBootstrapModule) {
      Get-PowerShellModuleInstallState -RegistryPath $StateRegistryPath -Name $Module.Name
    }
    $installedVersion = @($diskModule.Version, $trackedVersion) |
    Where-Object { $_ } |
    Sort-Object -Descending |
    Select-Object -First 1

    $galleryVersion = Invoke-WithRetry -Description "Find-Module $($Module.Name)" -ScriptBlock {
      (Find-Module -Name $Module.Name -Repository PSGallery -ErrorAction Stop).Version
    }
    $latestVersion = [version]$galleryVersion

    if ($installedVersion -and $installedVersion -ge $latestVersion) {
      Write-PwshProfileStatus -Stage 'Modules' -Type Current -Message "$($Module.Name) installed $installedVersion [latest] [$($Module.Scope)]"
      return 'Current'
    }

    if ($installedVersion) {
      Write-PwshProfileStatus -Stage 'Modules' -Type Action -Message "$($Module.Name) installed $installedVersion, updating to $latestVersion [$($Module.Scope)]"
    } else {
      Write-PwshProfileStatus -Stage 'Modules' -Type Action -Message "$($Module.Name) not installed, installing $latestVersion [$($Module.Scope)]"
    }

    # Save-Module always downloads into the exact path we give it. Install-Module was unreliable
    # here because it can decide an inbox/AllUsers copy (or an MSIX-packaged PowerShell's own
    # Modules folder) already "satisfies" the request and silently skip writing anywhere we'd
    # actually detect on the next run.
    $moduleRoot = Get-PowerShellModuleRoot
    if (-not (Test-Path -LiteralPath $moduleRoot)) {
      New-Item -ItemType Directory -Path $moduleRoot -Force -ErrorAction Stop | Out-Null
    }

    $previousProgressPreference = $ProgressPreference
    try {
      $ProgressPreference = 'SilentlyContinue'
      Invoke-WithRetry -Description "Save-Module $($Module.Name)" -ScriptBlock {
        Save-Module -Name $Module.Name -RequiredVersion $latestVersion -Repository PSGallery -Path $moduleRoot -Force -ErrorAction Stop
      } | Out-Null
    } finally {
      $ProgressPreference = $previousProgressPreference
    }

    if ($isBootstrapModule) {
      Set-PowerShellModuleInstallState -RegistryPath $StateRegistryPath -Name $Module.Name -Version $latestVersion
    }
    Remove-OldPowerShellModuleVersions -Name $Module.Name
    Write-PwshProfileStatus -Stage 'Modules' -Type Success -Message "$($Module.Name) ready at $latestVersion [$($Module.Scope)]"
    return 'Updated'
  } catch {
    Write-PwshProfileStatus -Stage 'Modules' -Type Warning -Message "$($Module.Name) failed: $($_.Exception.Message)"
    return 'Failed'
  }
}

function Show-PowerShellModuleInventory {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object[]] $Modules
  )

  Write-Host ''
  $Modules |
  Format-Table -Property `
  @{ Label = 'Module'; Expression = { $_.Name } },
  @{ Label = 'Scope'; Expression = { $_.Scope } } `
    -AutoSize |
  Out-String -Width 120 |
  ForEach-Object { $_ -split '\r?\n' } |
  ForEach-Object { $_.TrimEnd() } |
  Where-Object { $_ } |
  ForEach-Object { Write-PwshProfileStatus -Stage 'Modules' -Message $_ }
  Write-Host ''
}

function Compare-PwshProfileSemanticVersion {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $Left,

    [Parameter(Mandatory)]
    [string] $Right
  )

  $parseVersion = {
    param([string] $Value)

    $pattern = '^(?<core>(?<major>0|[1-9]\d*)\.(?<minor>0|[1-9]\d*)\.(?<patch>0|[1-9]\d*))(?:-(?<prerelease>(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*))?(?:\+(?<build>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$'
    if ($Value -notmatch $pattern) {
      throw "'$Value' is not a valid SemVer 2.0 version."
    }

    [pscustomobject]@{
      Core       = [version]$Matches.core
      Prerelease = if ($Matches.prerelease) { @($Matches.prerelease -split '\.') } else { @() }
    }
  }

  $leftVersion = & $parseVersion $Left
  $rightVersion = & $parseVersion $Right
  $coreComparison = $leftVersion.Core.CompareTo($rightVersion.Core)
  if ($coreComparison -ne 0) {
    return [Math]::Sign($coreComparison)
  }

  if ($leftVersion.Prerelease.Count -eq 0 -and $rightVersion.Prerelease.Count -eq 0) { return 0 }
  if ($leftVersion.Prerelease.Count -eq 0) { return 1 }
  if ($rightVersion.Prerelease.Count -eq 0) { return -1 }

  $identifierCount = [Math]::Max($leftVersion.Prerelease.Count, $rightVersion.Prerelease.Count)
  for ($index = 0; $index -lt $identifierCount; $index++) {
    if ($index -ge $leftVersion.Prerelease.Count) { return -1 }
    if ($index -ge $rightVersion.Prerelease.Count) { return 1 }

    $leftIdentifier = $leftVersion.Prerelease[$index]
    $rightIdentifier = $rightVersion.Prerelease[$index]
    $leftIsNumeric = $leftIdentifier -match '^\d+$'
    $rightIsNumeric = $rightIdentifier -match '^\d+$'
    if ($leftIsNumeric -and $rightIsNumeric) {
      $identifierComparison = [System.Numerics.BigInteger]::Parse($leftIdentifier).CompareTo(
        [System.Numerics.BigInteger]::Parse($rightIdentifier)
      )
    } elseif ($leftIsNumeric) {
      $identifierComparison = -1
    } elseif ($rightIsNumeric) {
      $identifierComparison = 1
    } else {
      $identifierComparison = [string]::CompareOrdinal($leftIdentifier, $rightIdentifier)
    }
    if ($identifierComparison -ne 0) {
      return [Math]::Sign($identifierComparison)
    }
  }

  0
}

function Get-PwshProfileReleasePages {
  [CmdletBinding()]
  param([string] $Uri, [hashtable] $Headers, [int] $TimeoutSec = 15)
  for ($page = 1; ; $page++) {
    # Invoke-RestMethod returns the JSON array as one pipeline object.
    # Assign it directly so filtering and pagination see individual releases.
    $items = Invoke-RestMethod -Uri "$Uri&page=$page" -Headers $Headers -TimeoutSec $TimeoutSec -ErrorAction Stop
    $items
    if ($items.Count -lt 100) { break }
  }
}

function Get-PwshProfileGitHubRelease {
  [CmdletBinding()]
  param (
    [string] $Repository = 'smoonlee/oh-my-posh-profile',

    [switch] $Prerelease
  )

  try {
    $releases = @(Get-PwshProfileReleasePages `
        -Uri "https://api.github.com/repos/$Repository/releases?per_page=100" `
        -Headers @{ 'User-Agent' = 'pwsh-profile-updater' } `
        -TimeoutSec 15 `
        -ErrorAction Stop)
  } catch {
    if ([int]$_.Exception.Response.StatusCode -eq 404) {
      return $null
    }
    throw "Could not query GitHub Releases for $Repository. $($_.Exception.Message)"
  }
  if (-not $Prerelease) {
    $release = $null
    $selectedVersion = $null
    foreach ($candidate in @($releases | Where-Object { -not $_.draft -and -not $_.prerelease })) {
      if ([string]$candidate.tag_name -notmatch '^v(?<version>(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?)$') {
        continue
      }
      $candidateVersion = $Matches.version
      if (-not $release -or
        (Compare-PwshProfileSemanticVersion -Left $candidateVersion -Right $selectedVersion) -gt 0) {
        $release = $candidate
        $selectedVersion = $candidateVersion
      }
    }
    return $release
  }
  $release = $null
  $selectedVersion = $null
  foreach ($candidate in @($releases | Where-Object { -not $_.draft -and $_.prerelease })) {
    if ([string]$candidate.tag_name -notmatch '^v(?<version>(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)-(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?)$') {
      continue
    }
    $candidateVersion = $Matches.version
    if (-not $release -or
      (Compare-PwshProfileSemanticVersion -Left $candidateVersion -Right $selectedVersion) -gt 0) {
      $release = $candidate
      $selectedVersion = $candidateVersion
    }
  }

  $release
}

function Import-PwshProfileConfiguration {
  [CmdletBinding()]
  param (
    [string] $Path = (Join-Path (Get-CrossPlatformSupportPaths).SourceRoot 'Microsoft.PowerShell_profile.ps1')
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    Write-PwshProfileStatus -Stage 'Profile' -Type Warning -Message "Could not load the PowerShell profile because it was not found: $Path"
    Write-Host ''
    return
  }

  try {
    Write-PwshProfileStatus -Stage 'Profile' -Type Action -Message "Reloading into the current session: $PROFILE"
    # Reload via $PROFILE itself so the running session ends up in the exact
    # state a brand new PowerShell window would start in.
    . $PROFILE
    Write-PwshProfileStatus -Stage 'Profile' -Type Success -Message 'PowerShell profile loaded into the current session.'
  } catch {
    Write-PwshProfileStatus -Stage 'Profile' -Type Warning -Message "Could not load the PowerShell profile: $($_.Exception.Message)"
  }
  Write-Host ''
}

function Get-PwshProfileLocalStorePaths {
  [CmdletBinding()]
  param ()

  $root = Join-Path $env:APPDATA 'PwshProfile'
  [pscustomobject]@{
    Root        = $root
    Themes      = Join-Path $root 'themes'
    Functions   = Join-Path $root 'functions'
    Modules     = Join-Path $root 'modules'
    Config      = Join-Path $root 'config'
    VersionFile = Join-Path $root 'version.json'
  }
}

function Save-PwshProfileReleaseAsset {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [uri] $Uri,

    [Parameter(Mandatory)]
    [string] $Destination
  )

  $previousProgressPreference = $ProgressPreference
  try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest `
      -Uri $Uri `
      -OutFile $Destination `
      -UseBasicParsing `
      -Headers @{ 'User-Agent' = 'pwsh-profile-updater' } `
      -ErrorAction Stop
  } catch {
    throw "Unable to download '$Uri'. $($_.Exception.Message)"
  } finally {
    $ProgressPreference = $previousProgressPreference
  }
}

function Get-PwshProfileNerdFontsCatalogSource {
  [CmdletBinding()]
  param (
    [string] $Repository = 'smoonlee/oh-my-posh-profile',

    [switch] $Prerelease,

    [switch] $LocalSource,

    [string] $SourceRoot
  )

  if ($LocalSource) {
    $catalogPath = Join-Path (Split-Path -Path $SourceRoot -Parent) 'NerdFontsCatalog.json'
    if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
      throw "Local Nerd Fonts catalog not found: $catalogPath"
    }
    return [pscustomobject]@{
      LocalPath  = $catalogPath
      ReleaseTag = 'local'
    }
  }

  $channel = if ($Prerelease) { 'prerelease' } else { 'stable' }
  $release = Get-PwshProfileGitHubRelease -Repository $Repository -Prerelease:$Prerelease
  if (-not $release) {
    if (-not $Prerelease) {
      Write-PwshProfileStatus -Stage 'Catalog' -Type Warning -Message "No published stable release was found for $Repository. Re-run with -Prerelease until a stable GA release is published."
    }
    throw "No published $channel release is available."
  }
  if ([string]$release.tag_name -notmatch '^v(?<version>(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:-(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?)$') {
    throw "Release tag '$($release.tag_name)' is not valid SemVer 2.0."
  }
  $releaseVersion = $Matches.version

  $releaseAssets = @{}
  foreach ($asset in @($release.assets)) {
    $releaseAssets[[string]$asset.name] = [string]$asset.browser_download_url
  }
  foreach ($requiredAsset in @('PwshProfile.release.json', 'NerdFontsCatalog.json')) {
    if (-not $releaseAssets.ContainsKey($requiredAsset)) {
      throw "Release $($release.tag_name) does not contain $requiredAsset. Publish a newer release with the complete asset bundle."
    }
  }

  try {
    $manifest = Invoke-RestMethod `
      -Uri $releaseAssets['PwshProfile.release.json'] `
      -Headers @{ 'User-Agent' = 'pwsh-profile-installer' } `
      -TimeoutSec 15 `
      -ErrorAction Stop
  } catch {
    throw "Could not retrieve the release manifest. $($_.Exception.Message)"
  }

  if ($manifest.schemaVersion -ne 1 -or
    [string]$manifest.version -ne $releaseVersion -or
    [string]$manifest.tag -ne [string]$release.tag_name -or
    [string]$manifest.channel -ne $channel -or
    [string]$manifest.repository -ne $Repository) {
    throw 'The release manifest does not match the selected GitHub Release metadata.'
  }

  $catalog = $manifest.artifacts.catalog
  if ([string]$catalog.asset -ne 'NerdFontsCatalog.json' -or
    [string]$catalog.sha256 -notmatch '^[a-fA-F0-9]{64}$') {
    throw 'The release manifest entry for the Nerd Fonts catalog is invalid.'
  }

  [pscustomobject]@{
    Uri        = [uri]$releaseAssets['NerdFontsCatalog.json']
    Sha256     = [string]$catalog.sha256
    ReleaseTag = [string]$release.tag_name
  }
}

function Test-PwshProfileScriptFile {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $Path,

    [Parameter(Mandatory)]
    [string] $Label
  )

  $tokens = $null
  $parseErrors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile(
    [System.IO.Path]::GetFullPath($Path),
    [ref]$tokens,
    [ref]$parseErrors
  )
  if ($parseErrors.Count -gt 0) {
    $messages = @($parseErrors | ForEach-Object { $_.Message }) -join '; '
    throw "$Label failed PowerShell syntax validation: $messages"
  }
}

function Install-PwshProfileAtomicFile {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $StagedPath,

    [Parameter(Mandatory)]
    [string] $Destination,

    [Parameter(Mandatory)]
    [string] $BackupPath
  )

  if ($script:PwshProfileJournalPath) {
    # Persist a recovery copy before touching the destination, including on a
    # filesystem where the subsequent replacement never completes.
    $existed = Test-Path -LiteralPath $Destination -PathType Leaf
    $recoveryPath = "$BackupPath.recovery"
    if ($existed) { Copy-Item -LiteralPath $Destination -Destination $recoveryPath -ErrorAction Stop }
    $script:PwshProfileJournal.Add([pscustomobject]@{ destination = $Destination; existed = $existed; backup = $recoveryPath })
    $journalTemporary = "$($script:PwshProfileJournalPath).tmp"
    [IO.File]::WriteAllText($journalTemporary, (ConvertTo-Json -InputObject @($script:PwshProfileJournal.ToArray()) -Depth 5), [Text.UTF8Encoding]::new($false))
    if (Test-Path -LiteralPath $script:PwshProfileJournalPath) { [IO.File]::Replace($journalTemporary, $script:PwshProfileJournalPath, "$($script:PwshProfileJournalPath).previous") }
    else { [IO.File]::Move($journalTemporary, $script:PwshProfileJournalPath) }
  }
  if (Test-Path -LiteralPath $Destination -PathType Leaf) {
    [System.IO.File]::Replace(
      [System.IO.Path]::GetFullPath($StagedPath),
      [System.IO.Path]::GetFullPath($Destination),
      [System.IO.Path]::GetFullPath($BackupPath),
      $true
    )
    return
  }

  [System.IO.File]::Move(
    [System.IO.Path]::GetFullPath($StagedPath),
    [System.IO.Path]::GetFullPath($Destination)
  )
}

function Install-PwshProfileLocalSource {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $SourceRoot,

    [switch] $Bootstrap
  )

  $operation = if ($Bootstrap) { 'Installation' } else { 'Update' }
  Write-PwshProfileHeader -Title "Pwsh Profile $operation" -Subtitle 'Validated Local Working Tree'

  $sourceRootPath = [System.IO.Path]::GetFullPath($SourceRoot)
  $sourcePaths = [ordered]@{
    profile                 = Join-Path $sourceRootPath 'profile\Microsoft.PowerShell_profile.ps1'
    theme                   = Join-Path $sourceRootPath 'themes\quick-term-cloud.omp.json'
    setup                   = Join-Path $sourceRootPath 'Invoke-PwshProfileSetup.ps1'
    publicIPManifest        = Join-Path $sourceRootPath 'modules\PwshProfile.PublicIP\PwshProfile.PublicIP.psd1'
    publicIPScript          = Join-Path $sourceRootPath 'modules\PwshProfile.PublicIP\PwshProfile.PublicIP.psm1'
    networkCidrManifest     = Join-Path $sourceRootPath 'modules\PwshProfile.NetworkCidr\PwshProfile.NetworkCidr.psd1'
    networkCidrScript       = Join-Path $sourceRootPath 'modules\PwshProfile.NetworkCidr\PwshProfile.NetworkCidr.psm1'
    networkCidrFormat       = Join-Path $sourceRootPath 'modules\PwshProfile.NetworkCidr\PwshProfile.NetworkCidr.Format.ps1xml'
    endOfLifeManifest       = Join-Path $sourceRootPath 'modules\PwshProfile.EndOfLife\PwshProfile.EndOfLife.psd1'
    endOfLifeScript         = Join-Path $sourceRootPath 'modules\PwshProfile.EndOfLife\PwshProfile.EndOfLife.psm1'
    endOfLifeFormat         = Join-Path $sourceRootPath 'modules\PwshProfile.EndOfLife\PwshProfile.EndOfLife.Format.ps1xml'
    azureKubernetesManifest = Join-Path $sourceRootPath 'modules\PwshProfile.AzureKubernetes\PwshProfile.AzureKubernetes.psd1'
    azureKubernetesScript   = Join-Path $sourceRootPath 'modules\PwshProfile.AzureKubernetes\PwshProfile.AzureKubernetes.psm1'
    dnsManifest             = Join-Path $sourceRootPath 'modules\PwshProfile.Dns\PwshProfile.Dns.psd1'
    dnsScript               = Join-Path $sourceRootPath 'modules\PwshProfile.Dns\PwshProfile.Dns.psm1'
    dnsFormat               = Join-Path $sourceRootPath 'modules\PwshProfile.Dns\PwshProfile.Dns.Format.ps1xml'
    tlsCertificateManifest  = Join-Path $sourceRootPath 'modules\PwshProfile.TlsCertificate\PwshProfile.TlsCertificate.psd1'
    tlsCertificateScript    = Join-Path $sourceRootPath 'modules\PwshProfile.TlsCertificate\PwshProfile.TlsCertificate.psm1'
    tlsCertificateFormat    = Join-Path $sourceRootPath 'modules\PwshProfile.TlsCertificate\PwshProfile.TlsCertificate.Format.ps1xml'
  }
  foreach ($name in $sourcePaths.Keys) {
    if (-not (Test-Path -LiteralPath $sourcePaths[$name] -PathType Leaf)) {
      Write-PwshProfileStatus -Stage $operation -Type Warning -Message "Local source '$name' was not found: $($sourcePaths[$name])"
      return $false
    }
  }

  $paths = Get-PwshProfileLocalStorePaths
  foreach ($folder in @($paths.Root, $paths.Themes, $paths.Functions, $paths.Modules, $paths.Config)) {
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
      New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop | Out-Null
    }
  }
  $destinations = [ordered]@{
    profile                 = Join-Path (Get-CrossPlatformSupportPaths).SourceRoot 'Microsoft.PowerShell_profile.ps1'
    theme                   = Join-Path $paths.Themes 'quick-term-cloud.omp.json'
    setup                   = Join-Path $paths.Functions 'Invoke-PwshProfileSetup.ps1'
    publicIPManifest        = Join-Path $paths.Modules 'PwshProfile.PublicIP\PwshProfile.PublicIP.psd1'
    publicIPScript          = Join-Path $paths.Modules 'PwshProfile.PublicIP\PwshProfile.PublicIP.psm1'
    networkCidrManifest     = Join-Path $paths.Modules 'PwshProfile.NetworkCidr\PwshProfile.NetworkCidr.psd1'
    networkCidrScript       = Join-Path $paths.Modules 'PwshProfile.NetworkCidr\PwshProfile.NetworkCidr.psm1'
    networkCidrFormat       = Join-Path $paths.Modules 'PwshProfile.NetworkCidr\PwshProfile.NetworkCidr.Format.ps1xml'
    endOfLifeManifest       = Join-Path $paths.Modules 'PwshProfile.EndOfLife\PwshProfile.EndOfLife.psd1'
    endOfLifeScript         = Join-Path $paths.Modules 'PwshProfile.EndOfLife\PwshProfile.EndOfLife.psm1'
    endOfLifeFormat         = Join-Path $paths.Modules 'PwshProfile.EndOfLife\PwshProfile.EndOfLife.Format.ps1xml'
    azureKubernetesManifest = Join-Path $paths.Modules 'PwshProfile.AzureKubernetes\PwshProfile.AzureKubernetes.psd1'
    azureKubernetesScript   = Join-Path $paths.Modules 'PwshProfile.AzureKubernetes\PwshProfile.AzureKubernetes.psm1'
    dnsManifest             = Join-Path $paths.Modules 'PwshProfile.Dns\PwshProfile.Dns.psd1'
    dnsScript               = Join-Path $paths.Modules 'PwshProfile.Dns\PwshProfile.Dns.psm1'
    dnsFormat               = Join-Path $paths.Modules 'PwshProfile.Dns\PwshProfile.Dns.Format.ps1xml'
    tlsCertificateManifest  = Join-Path $paths.Modules 'PwshProfile.TlsCertificate\PwshProfile.TlsCertificate.psd1'
    tlsCertificateScript    = Join-Path $paths.Modules 'PwshProfile.TlsCertificate\PwshProfile.TlsCertificate.psm1'
    tlsCertificateFormat    = Join-Path $paths.Modules 'PwshProfile.TlsCertificate\PwshProfile.TlsCertificate.Format.ps1xml'
  }

  Write-PwshProfileStatus -Stage $operation -Type Warning -Message 'Development mode: release metadata and remote asset verification are intentionally bypassed.'
  Write-PwshProfileStatus -Stage $operation -Message "Local source: $sourceRootPath"
  Write-Host ''

  try {
    Test-PwshProfileScriptFile -Path $sourcePaths.profile -Label 'Local profile'
    Test-PwshProfileScriptFile -Path $sourcePaths.setup -Label 'Local setup script'
    Test-PwshProfileScriptFile -Path $sourcePaths.publicIPScript -Label 'Local PublicIP module'
    $null = Import-PowerShellDataFile -LiteralPath $sourcePaths.publicIPManifest -ErrorAction Stop
    Test-PwshProfileScriptFile -Path $sourcePaths.networkCidrScript -Label 'Local NetworkCidr module'
    $null = Import-PowerShellDataFile -LiteralPath $sourcePaths.networkCidrManifest -ErrorAction Stop
    $null = [xml](Get-Content -LiteralPath $sourcePaths.networkCidrFormat -Raw -ErrorAction Stop)
    Test-PwshProfileScriptFile -Path $sourcePaths.endOfLifeScript -Label 'Local EndOfLife module'
    $null = Import-PowerShellDataFile -LiteralPath $sourcePaths.endOfLifeManifest -ErrorAction Stop
    $null = [xml](Get-Content -LiteralPath $sourcePaths.endOfLifeFormat -Raw -ErrorAction Stop)
    Test-PwshProfileScriptFile -Path $sourcePaths.azureKubernetesScript -Label 'Local AzureKubernetes module'
    $null = Import-PowerShellDataFile -LiteralPath $sourcePaths.azureKubernetesManifest -ErrorAction Stop
    Test-PwshProfileScriptFile -Path $sourcePaths.dnsScript -Label 'Local Dns module'
    $null = Import-PowerShellDataFile -LiteralPath $sourcePaths.dnsManifest -ErrorAction Stop
    $null = [xml](Get-Content -LiteralPath $sourcePaths.dnsFormat -Raw -ErrorAction Stop)
    Test-PwshProfileScriptFile -Path $sourcePaths.tlsCertificateScript -Label 'Local TlsCertificate module'
    $null = Import-PowerShellDataFile -LiteralPath $sourcePaths.tlsCertificateManifest -ErrorAction Stop
    $null = [xml](Get-Content -LiteralPath $sourcePaths.tlsCertificateFormat -Raw -ErrorAction Stop)
    $null = Get-Content -LiteralPath $sourcePaths.theme -Raw -ErrorAction Stop |
    ConvertFrom-Json -ErrorAction Stop
    $profileContent = Get-Content -LiteralPath $sourcePaths.profile -Raw -ErrorAction Stop
    if ($profileContent -notmatch "(?m)^\s*\`$script:PwshProfileVersion\s*=\s*'(?<version>(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:-(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?)'\s*$") {
      throw 'The local profile does not declare a valid SemVer 2.0 version.'
    }
    $localVersion = $Matches.version
  } catch {
    Write-PwshProfileStatus -Stage $operation -Type Warning -Message "Local source validation failed; no installed files were changed. $($_.Exception.Message)"
    return $false
  }

  $artifactNames = [ordered]@{
    profile                 = 'Microsoft.PowerShell_profile.ps1'
    theme                   = 'quick-term-cloud.omp.json'
    setup                   = 'Invoke-PwshProfileSetup.ps1'
    publicIPManifest        = 'PwshProfile.PublicIP.psd1'
    publicIPScript          = 'PwshProfile.PublicIP.psm1'
    networkCidrManifest     = 'PwshProfile.NetworkCidr.psd1'
    networkCidrScript       = 'PwshProfile.NetworkCidr.psm1'
    networkCidrFormat       = 'PwshProfile.NetworkCidr.Format.ps1xml'
    endOfLifeManifest       = 'PwshProfile.EndOfLife.psd1'
    endOfLifeScript         = 'PwshProfile.EndOfLife.psm1'
    endOfLifeFormat         = 'PwshProfile.EndOfLife.Format.ps1xml'
    azureKubernetesManifest = 'PwshProfile.AzureKubernetes.psd1'
    azureKubernetesScript   = 'PwshProfile.AzureKubernetes.psm1'
    dnsManifest             = 'PwshProfile.Dns.psd1'
    dnsScript               = 'PwshProfile.Dns.psm1'
    dnsFormat               = 'PwshProfile.Dns.Format.ps1xml'
    tlsCertificateManifest  = 'PwshProfile.TlsCertificate.psd1'
    tlsCertificateScript    = 'PwshProfile.TlsCertificate.psm1'
    tlsCertificateFormat    = 'PwshProfile.TlsCertificate.Format.ps1xml'
  }
  $artifactHashes = [ordered]@{}
  foreach ($name in $artifactNames.Keys) {
    $artifactHashes[$name] = (Get-FileHash -LiteralPath $sourcePaths[$name] -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-PwshProfileStatus -Stage 'Verify' -Type Success -Message "$($artifactNames[$name]) ($($artifactHashes[$name]))"
  }
  Write-PwshProfileStatus -Stage 'Verify' -Type Success -Message "PowerShell syntax, theme JSON, and embedded version $localVersion are valid."

  $stagedPaths = @{}
  $backupTimestamp = [DateTimeOffset]::UtcNow.ToString('yyyyMMddHHmmss')
  $backups = @{}
  $destinationExisted = @{}
  $replaced = [System.Collections.Generic.List[string]]::new()
  $versionTemporaryPath = "$($paths.VersionFile).$PID.tmp"
  try {
    foreach ($name in $artifactNames.Keys) {
      $destinationDirectory = Split-Path -Path $destinations[$name] -Parent
      if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $destinationDirectory -Force -ErrorAction Stop | Out-Null
      }
      $stagedPath = Join-Path $destinationDirectory ".$($artifactNames[$name]).$PID.local"
      Copy-Item -LiteralPath $sourcePaths[$name] -Destination $stagedPath -Force -ErrorAction Stop
      $stagedPaths[$name] = $stagedPath
      $stagedHash = (Get-FileHash -LiteralPath $stagedPath -Algorithm SHA256).Hash.ToLowerInvariant()
      if ($stagedHash -ine $artifactHashes[$name]) {
        throw "Local source '$name' changed while it was being staged. Run the command again."
      }
    }

    foreach ($name in $artifactNames.Keys) {
      $destinationExisted[$name] = Test-Path -LiteralPath $destinations[$name] -PathType Leaf
      if ($destinationExisted[$name]) {
        $localHash = (Get-FileHash -LiteralPath $destinations[$name] -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($localHash -ieq $artifactHashes[$name]) {
          Write-PwshProfileStatus -Stage 'Install' -Type Current -Message "Already verified: $($destinations[$name])"
          continue
        }
      }

      $backupPath = "$($destinations[$name]).$backupTimestamp.bak"
      Install-PwshProfileAtomicFile `
        -StagedPath $stagedPaths[$name] `
        -Destination $destinations[$name] `
        -BackupPath $backupPath
      $backups[$name] = $backupPath
      $replaced.Add($name)
      Write-PwshProfileStatus -Stage 'Install' -Type Success -Message "[Updated] $($destinations[$name])"
    }

    $installedManifest = [ordered]@{
      schemaVersion = 2
      version       = $localVersion
      tag           = $null
      channel       = 'local'
      repository    = 'smoonlee/oh-my-posh-profile'
      installedAt   = [DateTimeOffset]::UtcNow.ToString('o')
      artifacts     = [ordered]@{}
    }
    foreach ($name in $artifactNames.Keys) {
      $installedManifest.artifacts[$name] = [ordered]@{
        file   = $artifactNames[$name]
        sha256 = $artifactHashes[$name]
      }
    }
    $versionJson = $installedManifest | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText(
      [System.IO.Path]::GetFullPath($versionTemporaryPath),
      "$versionJson`n",
      [System.Text.UTF8Encoding]::new($false)
    )
    Install-PwshProfileAtomicFile -StagedPath $versionTemporaryPath -Destination $paths.VersionFile -BackupPath "$($paths.VersionFile).$backupTimestamp.bak"
  } catch {
    $installFailure = $_
    $rollbackErrors = @()
    foreach ($name in @($replaced)) {
      try {
        if ($backups.ContainsKey($name) -and (Test-Path -LiteralPath $backups[$name] -PathType Leaf)) {
          Copy-Item -LiteralPath $backups[$name] -Destination $destinations[$name] -Force -ErrorAction Stop
        } elseif (-not $destinationExisted[$name]) {
          Remove-Item -LiteralPath $destinations[$name] -Force -ErrorAction Stop
        } else { throw "Backup missing for $($destinations[$name])" }
      } catch { $rollbackErrors += "$($destinations[$name]): $($_.Exception.Message)" }
    }
    $recovery = if ($rollbackErrors.Count) { "Rollback incomplete: $($rollbackErrors -join '; '). Retained backups: $($backups.Values -join ', ')" } else { 'Previous files were restored.' }
    Write-PwshProfileStatus -Stage $operation -Type Warning -Message "Local installation failed. $($installFailure.Exception.Message) $recovery"
    return $false
  } finally {
    foreach ($stagedPath in $stagedPaths.Values) {
      Remove-Item -LiteralPath $stagedPath -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $versionTemporaryPath -Force -ErrorAction SilentlyContinue
  }

  Remove-Item -LiteralPath (Join-Path $paths.Root 'update-state.json') -Force -ErrorAction SilentlyContinue
  $completedAction = if ($Bootstrap) { 'Installed' } else { 'Updated' }
  Write-PwshProfileStatus -Stage 'Complete' -Type Success -Message "$completedAction Pwsh Profile v$localVersion from validated local source files."
  if (-not $Bootstrap) {
    Write-PwshProfileStatus -Stage 'Next' -Type Action -Message 'Open a new PowerShell session to load the updated profile.'
  }
  Write-Host ''
  return $true
}

function Invoke-PwshProfileUpdateTransaction {
  param([scriptblock] $Action)
  $paths = Get-PwshProfileLocalStorePaths
  $null = New-Item -ItemType Directory -Path $paths.Root -Force
  $lockPath = Join-Path $paths.Root 'update.lock'
  try { $lock = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None') }
  catch { throw 'Another profile update is running. Retry after it completes.' }
  $journalPath = Join-Path $paths.Root 'update-journal.json'
  try {
    if (Test-Path -LiteralPath $journalPath) {
      $journal = Get-Content $journalPath -Raw | ConvertFrom-Json -ErrorAction Stop
      # Recovery is deliberately explicit: never overwrite files edited after a crash.
      throw "An interrupted update requires recovery. Journal: $journalPath. Restore the backups listed there, then remove the journal before retrying."
    }
    $script:PwshProfileJournalPath = $journalPath
    $script:PwshProfileJournal = [Collections.Generic.List[object]]::new()
    $result = & $Action
    # A normal return means the implementation completed or handled its rollback.
    # Keep failed transactions available for explicit recovery and inspection.
    if ($result -eq $true) { Remove-Item -LiteralPath $journalPath -Force -ErrorAction SilentlyContinue }
    $result
  } finally {
    try {
      if ($script:PwshProfileJournal -and (Test-Path -LiteralPath $journalPath)) {
        $restored = $true
        foreach ($entry in $script:PwshProfileJournal) {
          if ($entry.existed) {
            if (-not (Test-Path -LiteralPath $entry.destination) -or
              (Get-FileHash -LiteralPath $entry.destination).Hash -ne (Get-FileHash -LiteralPath $entry.backup).Hash) { $restored = $false }
          } elseif (Test-Path -LiteralPath $entry.destination) { $restored = $false }
        }
        if ($restored) { Remove-Item -LiteralPath $journalPath -Force }
      }
    } catch { Write-Warning "Recovery journal retained: $journalPath" }
    $script:PwshProfileJournalPath = $null
    $script:PwshProfileJournal = $null
    $lock.Dispose()
  }
}

function Invoke-PwshProfileUpdate {
  [CmdletBinding()]
  param([string] $Repository = 'smoonlee/oh-my-posh-profile', [switch] $Prerelease, [switch] $Bootstrap, [switch] $LocalSource)
  Invoke-PwshProfileUpdateTransaction { Invoke-PwshProfileUpdateCore -Repository $Repository -Prerelease:$Prerelease -Bootstrap:$Bootstrap -LocalSource:$LocalSource }
}

function Invoke-PwshProfileUpdateCore {
  [CmdletBinding()]
  param (
    [string] $Repository = 'smoonlee/oh-my-posh-profile',

    [switch] $Prerelease,

    [switch] $Bootstrap,

    [switch] $LocalSource
  )

  if ($LocalSource) {
    return Install-PwshProfileLocalSource -SourceRoot $PSScriptRoot -Bootstrap:$Bootstrap
  }

  $operation = if ($Bootstrap) { 'Installation' } else { 'Update' }
  Write-PwshProfileHeader -Title "Pwsh Profile $operation" -Subtitle 'Verified GitHub Release Assets'

  $paths = Get-PwshProfileLocalStorePaths
  foreach ($folder in @($paths.Root, $paths.Themes, $paths.Functions, $paths.Modules, $paths.Config)) {
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
      New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop | Out-Null
    }
  }
  $profilePath = Join-Path (Get-CrossPlatformSupportPaths).SourceRoot 'Microsoft.PowerShell_profile.ps1'
  $themePath = Join-Path $paths.Themes 'quick-term-cloud.omp.json'
  $setupPath = Join-Path $paths.Functions 'Invoke-PwshProfileSetup.ps1'
  $publicIPManifestPath = Join-Path $paths.Modules 'PwshProfile.PublicIP\PwshProfile.PublicIP.psd1'
  $publicIPScriptPath = Join-Path $paths.Modules 'PwshProfile.PublicIP\PwshProfile.PublicIP.psm1'
  $networkCidrManifestPath = Join-Path $paths.Modules 'PwshProfile.NetworkCidr\PwshProfile.NetworkCidr.psd1'
  $networkCidrScriptPath = Join-Path $paths.Modules 'PwshProfile.NetworkCidr\PwshProfile.NetworkCidr.psm1'
  $networkCidrFormatPath = Join-Path $paths.Modules 'PwshProfile.NetworkCidr\PwshProfile.NetworkCidr.Format.ps1xml'
  $endOfLifeManifestPath = Join-Path $paths.Modules 'PwshProfile.EndOfLife\PwshProfile.EndOfLife.psd1'
  $endOfLifeScriptPath = Join-Path $paths.Modules 'PwshProfile.EndOfLife\PwshProfile.EndOfLife.psm1'
  $endOfLifeFormatPath = Join-Path $paths.Modules 'PwshProfile.EndOfLife\PwshProfile.EndOfLife.Format.ps1xml'
  $azureKubernetesManifestPath = Join-Path $paths.Modules 'PwshProfile.AzureKubernetes\PwshProfile.AzureKubernetes.psd1'
  $azureKubernetesScriptPath = Join-Path $paths.Modules 'PwshProfile.AzureKubernetes\PwshProfile.AzureKubernetes.psm1'
  $dnsManifestPath = Join-Path $paths.Modules 'PwshProfile.Dns\PwshProfile.Dns.psd1'
  $dnsScriptPath = Join-Path $paths.Modules 'PwshProfile.Dns\PwshProfile.Dns.psm1'
  $dnsFormatPath = Join-Path $paths.Modules 'PwshProfile.Dns\PwshProfile.Dns.Format.ps1xml'
  $tlsCertificateManifestPath = Join-Path $paths.Modules 'PwshProfile.TlsCertificate\PwshProfile.TlsCertificate.psd1'
  $tlsCertificateScriptPath = Join-Path $paths.Modules 'PwshProfile.TlsCertificate\PwshProfile.TlsCertificate.psm1'
  $tlsCertificateFormatPath = Join-Path $paths.Modules 'PwshProfile.TlsCertificate\PwshProfile.TlsCertificate.Format.ps1xml'
  $destinations = [ordered]@{
    profile                 = $profilePath
    theme                   = $themePath
    setup                   = $setupPath
    publicIPManifest        = $publicIPManifestPath
    publicIPScript          = $publicIPScriptPath
    networkCidrManifest     = $networkCidrManifestPath
    networkCidrScript       = $networkCidrScriptPath
    networkCidrFormat       = $networkCidrFormatPath
    endOfLifeManifest       = $endOfLifeManifestPath
    endOfLifeScript         = $endOfLifeScriptPath
    endOfLifeFormat         = $endOfLifeFormatPath
    azureKubernetesManifest = $azureKubernetesManifestPath
    azureKubernetesScript   = $azureKubernetesScriptPath
    dnsManifest             = $dnsManifestPath
    dnsScript               = $dnsScriptPath
    dnsFormat               = $dnsFormatPath
    tlsCertificateManifest  = $tlsCertificateManifestPath
    tlsCertificateScript    = $tlsCertificateScriptPath
    tlsCertificateFormat    = $tlsCertificateFormatPath
  }

  $installed = $null
  if (Test-Path -LiteralPath $paths.VersionFile -PathType Leaf) {
    try {
      $candidateManifest = Get-Content -LiteralPath $paths.VersionFile -Raw -ErrorAction Stop |
      ConvertFrom-Json -ErrorAction Stop
      if ($candidateManifest.schemaVersion -eq 2 -and
        $candidateManifest.version -and
        $candidateManifest.artifacts) {
        $installed = $candidateManifest
      } elseif (-not $Bootstrap) {
        Write-PwshProfileStatus -Stage 'Update' -Type Warning -Message 'The legacy OTA baseline must be migrated by running the Profile setup phase.'
        return $false
      }
    } catch {
      if (-not $Bootstrap) {
        Write-PwshProfileStatus -Stage 'Update' -Type Warning -Message "The local version manifest is invalid: $($_.Exception.Message)"
        return $false
      }
      Write-PwshProfileStatus -Stage 'Install' -Type Warning -Message 'The existing version manifest is invalid and will be replaced only after release verification succeeds.'
    }
  } elseif (-not $Bootstrap) {
    Write-PwshProfileStatus -Stage 'Update' -Type Warning -Message 'No tracked installation baseline was found. Run the Profile setup phase first.'
    return $false
  }

  $currentVersion = $null
  if ($installed) {
    try {
      [void](Compare-PwshProfileSemanticVersion -Left ([string]$installed.version) -Right ([string]$installed.version))
      $currentVersion = [string]$installed.version
    } catch {
      if (-not $Bootstrap) {
        Write-PwshProfileStatus -Stage 'Update' -Type Warning -Message "The installed version '$($installed.version)' is not valid SemVer."
        return $false
      }
      $installed = $null
      Write-PwshProfileStatus -Stage 'Install' -Type Warning -Message 'The existing baseline version is invalid and will not be trusted.'
    }
  }

  $channel = if ($Prerelease) { 'prerelease' } else { 'stable' }
  if ($currentVersion) {
    Write-PwshProfileStatus -Stage $operation -Message "Installed version: $currentVersion"
  }
  Write-PwshProfileStatus -Stage $operation -Message "Requested channel: $channel"
  try {
    $release = Get-PwshProfileGitHubRelease -Repository $Repository -Prerelease:$Prerelease
  } catch {
    Write-PwshProfileStatus -Stage $operation -Type Warning -Message "Could not query the latest $channel GitHub Release: $($_.Exception.Message)"
    return $false
  }

  if (-not $release) {
    Write-PwshProfileStatus -Stage $operation -Type Warning -Message "No $channel GitHub Release is available."
    if (-not $Prerelease) {
      Write-PwshProfileStatus -Stage 'Next' -Message 'Use -Prerelease only when you intentionally want to install a published prerelease.'
    }
    return $false
  }

  if ($release.draft -or
    [bool]$release.prerelease -ne [bool]$Prerelease -or
    [string]$release.tag_name -notmatch '^v(?<version>(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:-(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?)$') {
    Write-PwshProfileStatus -Stage $operation -Type Warning -Message "The latest $channel release tag '$($release.tag_name)' is not valid for the requested channel."
    return $false
  }

  $latestVersionText = $Matches.version
  Write-PwshProfileStatus -Stage $operation -Message "Selected release: $($release.tag_name)"
  Write-Host ''

  $drift = [System.Collections.Generic.List[string]]::new()
  if ($installed) {
    foreach ($name in $destinations.Keys) {
      $installedArtifact = $installed.artifacts.PSObject.Properties[$name]
      if (-not $installedArtifact) {
        # A newer release may introduce an asset that was not part of the
        # installed baseline. It has no local state to verify yet.
        continue
      }
      $path = $destinations[$name]
      $expectedHash = [string]$installedArtifact.Value.sha256
      if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $drift.Add("$name is missing: $path")
        continue
      }
      $actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
      if ($actualHash -ine $expectedHash) {
        $drift.Add("$name was modified: $path")
      }
    }
  }
  if ($drift.Count -gt 0 -and -not $Bootstrap) {
    Write-PwshProfileStatus -Stage 'Update' -Type Warning -Message 'Update refused because tracked files differ from the installed baseline.'
    foreach ($item in $drift) {
      Write-PwshProfileStatus -Stage 'Drift' -Type Warning -Message $item
    }
    Write-PwshProfileStatus -Stage 'Next' -Message 'Restore the tracked files or run the Profile setup phase to intentionally establish a new baseline.'
    return $false
  }
  if (-not $Bootstrap) {
    $versionComparison = Compare-PwshProfileSemanticVersion `
      -Left $latestVersionText `
      -Right $currentVersion
    $missingBaselineArtifacts = @(
      $destinations.Keys | Where-Object {
        -not $installed.artifacts.PSObject.Properties[$_]
      }
    )

    if ($versionComparison -lt 0 -or
      ($versionComparison -eq 0 -and $missingBaselineArtifacts.Count -eq 0)) {
      Write-PwshProfileStatus -Stage 'Update' -Type Current -Message 'Already up to date.'
      Write-Host ''
      return $true
    }

    if ($versionComparison -eq 0) {
      Write-PwshProfileStatus `
        -Stage 'Repair' `
        -Type Action `
        -Message "Restoring $($missingBaselineArtifacts.Count) newly tracked release asset(s)..."
    }
  }

  $releaseAssets = @{}
  foreach ($asset in @($release.assets)) {
    $releaseAssets[[string]$asset.name] = [string]$asset.browser_download_url
  }
  $manifestAssetName = 'PwshProfile.release.json'
  if (-not $releaseAssets.ContainsKey($manifestAssetName)) {
    Write-PwshProfileStatus -Stage 'Update' -Type Warning -Message "Release $($release.tag_name) does not contain $manifestAssetName."
    return $false
  }

  $manifestTemporaryPath = Join-Path $paths.Root ".$manifestAssetName.$PID.tmp"
  try {
    Save-PwshProfileReleaseAsset -Uri $releaseAssets[$manifestAssetName] -Destination $manifestTemporaryPath
    $remoteManifest = Get-Content -LiteralPath $manifestTemporaryPath -Raw -ErrorAction Stop |
    ConvertFrom-Json -ErrorAction Stop
  } catch {
    Write-PwshProfileStatus -Stage 'Update' -Type Warning -Message "Could not retrieve the release manifest: $($_.Exception.Message)"
    return $false
  } finally {
    Remove-Item -LiteralPath $manifestTemporaryPath -Force -ErrorAction SilentlyContinue
  }

  if ($remoteManifest.schemaVersion -ne 1 -or
    [string]$remoteManifest.version -ne $latestVersionText -or
    [string]$remoteManifest.tag -ne [string]$release.tag_name -or
    [string]$remoteManifest.channel -ne $channel -or
    [string]$remoteManifest.repository -ne $Repository) {
    Write-PwshProfileStatus -Stage 'Update' -Type Warning -Message 'The release manifest does not match the GitHub Release metadata.'
    return $false
  }

  $artifactNames = [ordered]@{
    profile                 = 'Microsoft.PowerShell_profile.ps1'
    theme                   = 'quick-term-cloud.omp.json'
    setup                   = 'Invoke-PwshProfileSetup.ps1'
    publicIPManifest        = 'PwshProfile.PublicIP.psd1'
    publicIPScript          = 'PwshProfile.PublicIP.psm1'
    networkCidrManifest     = 'PwshProfile.NetworkCidr.psd1'
    networkCidrScript       = 'PwshProfile.NetworkCidr.psm1'
    networkCidrFormat       = 'PwshProfile.NetworkCidr.Format.ps1xml'
    endOfLifeManifest       = 'PwshProfile.EndOfLife.psd1'
    endOfLifeScript         = 'PwshProfile.EndOfLife.psm1'
    endOfLifeFormat         = 'PwshProfile.EndOfLife.Format.ps1xml'
    azureKubernetesManifest = 'PwshProfile.AzureKubernetes.psd1'
    azureKubernetesScript   = 'PwshProfile.AzureKubernetes.psm1'
    dnsManifest             = 'PwshProfile.Dns.psd1'
    dnsScript               = 'PwshProfile.Dns.psm1'
    dnsFormat               = 'PwshProfile.Dns.Format.ps1xml'
    tlsCertificateManifest  = 'PwshProfile.TlsCertificate.psd1'
    tlsCertificateScript    = 'PwshProfile.TlsCertificate.psm1'
    tlsCertificateFormat    = 'PwshProfile.TlsCertificate.Format.ps1xml'
  }
  $stagedPaths = @{}
  try {
    foreach ($name in $artifactNames.Keys) {
      $artifact = $remoteManifest.artifacts.$name
      $assetName = $artifactNames[$name]
      $expectedHash = [string]$artifact.sha256
      if ([string]$artifact.asset -ne $assetName -or
        $expectedHash -notmatch '^[a-fA-F0-9]{64}$' -or
        -not $releaseAssets.ContainsKey($assetName)) {
        throw "The release manifest entry for '$name' is invalid."
      }

      $destinationDirectory = Split-Path -Path $destinations[$name] -Parent
      if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $destinationDirectory -Force -ErrorAction Stop | Out-Null
      }
      $stagedPath = Join-Path $destinationDirectory ".$assetName.$PID.update"
      $stagedPaths[$name] = $stagedPath
      Save-PwshProfileReleaseAsset -Uri $releaseAssets[$assetName] -Destination $stagedPath
      $actualHash = (Get-FileHash -LiteralPath $stagedPath -Algorithm SHA256).Hash.ToLowerInvariant()
      if ($actualHash -ine $expectedHash) {
        throw "SHA-256 verification failed for '$assetName'."
      }
      Write-PwshProfileStatus -Stage 'Verify' -Type Success -Message "$assetName ($actualHash)"
    }

    Test-PwshProfileScriptFile -Path $stagedPaths.profile -Label 'Profile'
    Test-PwshProfileScriptFile -Path $stagedPaths.setup -Label 'Setup script'
    Test-PwshProfileScriptFile -Path $stagedPaths.publicIPScript -Label 'PublicIP module'
    $null = Import-PowerShellDataFile -LiteralPath $stagedPaths.publicIPManifest -ErrorAction Stop
    Test-PwshProfileScriptFile -Path $stagedPaths.networkCidrScript -Label 'NetworkCidr module'
    $null = Import-PowerShellDataFile -LiteralPath $stagedPaths.networkCidrManifest -ErrorAction Stop
    $null = [xml](Get-Content -LiteralPath $stagedPaths.networkCidrFormat -Raw -ErrorAction Stop)
    Test-PwshProfileScriptFile -Path $stagedPaths.endOfLifeScript -Label 'EndOfLife module'
    $null = Import-PowerShellDataFile -LiteralPath $stagedPaths.endOfLifeManifest -ErrorAction Stop
    $null = [xml](Get-Content -LiteralPath $stagedPaths.endOfLifeFormat -Raw -ErrorAction Stop)
    Test-PwshProfileScriptFile -Path $stagedPaths.azureKubernetesScript -Label 'AzureKubernetes module'
    $null = Import-PowerShellDataFile -LiteralPath $stagedPaths.azureKubernetesManifest -ErrorAction Stop
    Test-PwshProfileScriptFile -Path $stagedPaths.dnsScript -Label 'Dns module'
    $null = Import-PowerShellDataFile -LiteralPath $stagedPaths.dnsManifest -ErrorAction Stop
    $null = [xml](Get-Content -LiteralPath $stagedPaths.dnsFormat -Raw -ErrorAction Stop)
    Test-PwshProfileScriptFile -Path $stagedPaths.tlsCertificateScript -Label 'TlsCertificate module'
    $null = Import-PowerShellDataFile -LiteralPath $stagedPaths.tlsCertificateManifest -ErrorAction Stop
    $null = [xml](Get-Content -LiteralPath $stagedPaths.tlsCertificateFormat -Raw -ErrorAction Stop)
    $null = Get-Content -LiteralPath $stagedPaths.theme -Raw -ErrorAction Stop |
    ConvertFrom-Json -ErrorAction Stop
    $profileContent = Get-Content -LiteralPath $stagedPaths.profile -Raw -ErrorAction Stop
    if ($profileContent -notmatch "(?m)^\s*\`$script:PwshProfileVersion\s*=\s*'$([regex]::Escape($latestVersionText))'\s*$") {
      throw "The downloaded profile does not declare version '$latestVersionText'."
    }
    Write-PwshProfileStatus -Stage 'Verify' -Type Success -Message 'PowerShell syntax, theme JSON, and embedded version are valid.'
  } catch {
    foreach ($stagedPath in $stagedPaths.Values) {
      Remove-Item -LiteralPath $stagedPath -Force -ErrorAction SilentlyContinue
    }
    Write-PwshProfileStatus -Stage $operation -Type Warning -Message "Release validation failed; no installed files were changed. $($_.Exception.Message)"
    return $false
  }

  if (-not $Bootstrap) {
    try {
      Protect-PwshProfileNewerModules -ArtifactNames $artifactNames -Destinations $destinations -StagedPaths $stagedPaths -InstalledBaseline $installed -ReleaseManifest $remoteManifest
    } catch {
      foreach ($path in $stagedPaths.Values) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
      Write-PwshProfileStatus -Stage 'Update' -Type Warning -Message $_.Exception.Message
      return $false
    }
  }

  if ($Bootstrap) {
    $conflicts = [System.Collections.Generic.List[string]]::new()
    foreach ($name in $artifactNames.Keys) {
      if (-not (Test-Path -LiteralPath $destinations[$name] -PathType Leaf)) {
        continue
      }
      $localHash = (Get-FileHash -LiteralPath $destinations[$name] -Algorithm SHA256).Hash.ToLowerInvariant()
      $releaseHash = ([string]$remoteManifest.artifacts.$name.sha256).ToLowerInvariant()
      if ($localHash -ine $releaseHash) {
        $conflicts.Add("$name differs: $($destinations[$name])")
      }
    }

    if ($conflicts.Count -gt 0) {
      Write-PwshProfileStatus -Stage 'Install' -Type Warning -Message "Published release $($release.tag_name) differs from existing local files."
      foreach ($conflict in $conflicts) {
        Write-PwshProfileStatus -Stage 'Conflict' -Type Warning -Message $conflict
      }
      $confirmation = Read-Host -Prompt 'Replace these files with verified release assets? Timestamped backups will be retained. (y/N)'
      if ($confirmation -notmatch '(?i)^y(es)?$') {
        foreach ($stagedPath in $stagedPaths.Values) {
          Remove-Item -LiteralPath $stagedPath -Force -ErrorAction SilentlyContinue
        }
        Write-PwshProfileStatus -Stage 'Install' -Type Warning -Message 'Skipped: user declined to install the published release.'
        return $false
      }
    }
  }

  $backupTimestamp = [DateTimeOffset]::UtcNow.ToString('yyyyMMddHHmmss')
  $backups = @{}
  $destinationExisted = @{}
  $replaced = [System.Collections.Generic.List[string]]::new()
  try {
    foreach ($name in $artifactNames.Keys) {
      $destinationExisted[$name] = Test-Path -LiteralPath $destinations[$name] -PathType Leaf
      if ($destinationExisted[$name]) {
        $localHash = (Get-FileHash -LiteralPath $destinations[$name] -Algorithm SHA256).Hash.ToLowerInvariant()
        $releaseHash = ([string]$remoteManifest.artifacts.$name.sha256).ToLowerInvariant()
        if ($localHash -ieq $releaseHash) {
          Write-PwshProfileStatus -Stage 'Install' -Type Current -Message "Already verified: $($destinations[$name])"
          continue
        }
      }

      $backupPath = "$($destinations[$name]).$backupTimestamp.bak"
      Install-PwshProfileAtomicFile `
        -StagedPath $stagedPaths[$name] `
        -Destination $destinations[$name] `
        -BackupPath $backupPath
      $backups[$name] = $backupPath
      $replaced.Add($name)
      Write-PwshProfileStatus -Stage 'Install' -Type Success -Message "[Updated] $($destinations[$name])"
    }

    $installedManifest = [ordered]@{
      schemaVersion = 2
      version       = $latestVersionText
      tag           = [string]$release.tag_name
      channel       = $channel
      repository    = $Repository
      installedAt   = [DateTimeOffset]::UtcNow.ToString('o')
      artifacts     = [ordered]@{}
    }
    foreach ($name in $artifactNames.Keys) {
      $installedManifest.artifacts[$name] = [ordered]@{
        file   = $artifactNames[$name]
        sha256 = ([string]$remoteManifest.artifacts.$name.sha256).ToLowerInvariant()
      }
    }
    $versionJson = $installedManifest | ConvertTo-Json -Depth 8
    $versionTemporaryPath = "$($paths.VersionFile).$PID.tmp"
    [System.IO.File]::WriteAllText(
      [System.IO.Path]::GetFullPath($versionTemporaryPath),
      "$versionJson`n",
      [System.Text.UTF8Encoding]::new($false)
    )
    Install-PwshProfileAtomicFile -StagedPath $versionTemporaryPath -Destination $paths.VersionFile -BackupPath "$($paths.VersionFile).$backupTimestamp.bak"
  } catch {
    $installFailure = $_
    $rollbackErrors = @()
    foreach ($name in @($replaced)) {
      try {
        if ($backups.ContainsKey($name) -and (Test-Path -LiteralPath $backups[$name] -PathType Leaf)) {
          Copy-Item -LiteralPath $backups[$name] -Destination $destinations[$name] -Force -ErrorAction Stop
        } elseif (-not $destinationExisted[$name]) {
          Remove-Item -LiteralPath $destinations[$name] -Force -ErrorAction Stop
        } else { throw "Backup missing for $($destinations[$name])" }
      } catch { $rollbackErrors += "$($destinations[$name]): $($_.Exception.Message)" }
    }
    $recovery = if ($rollbackErrors.Count) { "Rollback incomplete: $($rollbackErrors -join '; '). Retained backups: $($backups.Values -join ', ')" } else { 'Previous files were restored.' }
    Write-PwshProfileStatus -Stage $operation -Type Warning -Message "Installation failed. $($installFailure.Exception.Message) $recovery"
    return $false
  } finally {
    foreach ($stagedPath in $stagedPaths.Values) {
      Remove-Item -LiteralPath $stagedPath -Force -ErrorAction SilentlyContinue
    }
  }

  Remove-Item -LiteralPath (Join-Path $paths.Root 'update-state.json') -Force -ErrorAction SilentlyContinue
  $completedAction = if ($Bootstrap) { 'Installed' } else { 'Updated' }
  Write-PwshProfileStatus -Stage 'Complete' -Type Success -Message "$completedAction Pwsh Profile v$latestVersionText from verified $channel release assets."
  if (-not $Bootstrap) {
    Write-PwshProfileStatus -Stage 'Next' -Type Action -Message 'Open a new PowerShell session to load the updated profile.'
  }
  Write-Host ''
  return $true
}

function Get-PwshProfileModuleGitHubRelease {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $ModuleName,

    [string] $Repository = 'smoonlee/oh-my-posh-profile',

    [switch] $Prerelease,

    [object[]] $Releases
  )

  if (-not $PSBoundParameters.ContainsKey('Releases')) {
    try {
      $Releases = @(Get-PwshProfileReleasePages `
          -Uri "https://api.github.com/repos/$Repository/releases?per_page=100" `
          -Headers @{ 'User-Agent' = 'pwsh-profile-module-updater' } `
          -TimeoutSec 15 `
          -ErrorAction Stop)
    } catch {
      throw "Could not query module releases for $ModuleName. $($_.Exception.Message)"
    }
  }

  $escapedName = [regex]::Escape($ModuleName)
  $selected = $null
  $selectedVersion = $null
  foreach ($candidate in @($Releases | Where-Object { -not $_.draft })) {
    if ([string]$candidate.tag_name -notmatch "^$escapedName-v(?<version>(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:-(?<prerelease>(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?)$") {
      continue
    }
    $candidateVersion = $Matches.version
    $isPrerelease = [bool]$Matches.prerelease
    if ([bool]$candidate.prerelease -ne $isPrerelease -or ($isPrerelease -and -not $Prerelease)) {
      continue
    }
    if (-not $selected -or
      (Compare-PwshProfileSemanticVersion -Left $candidateVersion -Right $selectedVersion) -gt 0) {
      $selected = $candidate
      $selectedVersion = $candidateVersion
    }
  }
  $selected
}

function Protect-PwshProfileNewerModules {
  param($ArtifactNames, $Destinations, $StagedPaths, $InstalledBaseline, $ReleaseManifest)

  foreach ($key in $ArtifactNames.Keys) {
    $file = [string]$ArtifactNames[$key]
    if ($file -notmatch '^(PwshProfile\..+)\.psd1$') { continue }
    $moduleName = $Matches[1]
    if (-not (Test-Path -LiteralPath $Destinations[$key] -PathType Leaf)) { continue }
    $localVersion = [string](Import-PowerShellDataFile -LiteralPath $Destinations[$key]).ModuleVersion
    $bundleVersion = [string](Import-PowerShellDataFile -LiteralPath $StagedPaths[$key]).ModuleVersion
    if ((Compare-PwshProfileSemanticVersion -Left $localVersion -Right $bundleVersion) -le 0) { continue }
    foreach ($assetKey in $ArtifactNames.Keys) {
      if ([string]$ArtifactNames[$assetKey] -notlike "$moduleName.*") { continue }
      $baselineEntry = $InstalledBaseline.artifacts.PSObject.Properties[$assetKey]
      if (-not $baselineEntry) { throw "Cannot preserve $moduleName without a verified baseline for $assetKey." }
      $actualHash = (Get-FileHash -LiteralPath $Destinations[$assetKey] -Algorithm SHA256 -ErrorAction Stop).Hash
      if ($actualHash -ine $baselineEntry.Value.sha256) { throw "Cannot preserve modified module asset: $assetKey" }
      Copy-Item -LiteralPath $Destinations[$assetKey] -Destination $StagedPaths[$assetKey] -Force -ErrorAction Stop
      if ((Get-FileHash -LiteralPath $StagedPaths[$assetKey] -Algorithm SHA256).Hash -ine $actualHash) {
        throw "Module asset changed while being preserved: $assetKey"
      }
      $ReleaseManifest.artifacts.$assetKey.sha256 = $actualHash.ToLowerInvariant()
    }
    Write-PwshProfileStatus -Stage 'Module' -Type Current -Message "Preserving $moduleName $localVersion; bundle contains $bundleVersion."
  }
}

function Invoke-PwshProfileModuleUpdate {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string] $ModuleName, [string] $Repository = 'smoonlee/oh-my-posh-profile', [switch] $Prerelease, [object[]] $Releases)
  $parameters = @{} + $PSBoundParameters
  Invoke-PwshProfileUpdateTransaction { Invoke-PwshProfileModuleUpdateCore @parameters }
}

function Invoke-PwshProfileModuleUpdateCore {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $ModuleName,

    [string] $Repository = 'smoonlee/oh-my-posh-profile',

    [switch] $Prerelease,

    [object[]] $Releases
  )

  $releaseParameters = @{
    ModuleName = $ModuleName
    Repository = $Repository
    Prerelease = $Prerelease
  }
  if ($PSBoundParameters.ContainsKey('Releases')) { $releaseParameters.Releases = $Releases }
  $release = Get-PwshProfileModuleGitHubRelease @releaseParameters
  if (-not $release) {
    Write-PwshProfileStatus -Stage 'Module' -Type Current -Message "No independent release is published for $ModuleName."
    return $true
  }
  if ([string]$release.tag_name -notmatch "-v(?<version>[^/]+)$") {
    throw "Module release tag '$($release.tag_name)' is invalid."
  }
  $latestVersion = $Matches.version
  $paths = Get-PwshProfileLocalStorePaths
  $moduleRoot = Join-Path $paths.Modules $ModuleName
  $installedManifestPath = Join-Path $moduleRoot "$ModuleName.psd1"
  $installedVersion = '0.0.0'
  if (Test-Path -LiteralPath $installedManifestPath -PathType Leaf) {
    try {
      $installedVersion = [string](Import-PowerShellDataFile -LiteralPath $installedManifestPath -ErrorAction Stop).ModuleVersion
    } catch {
      throw "The installed $ModuleName manifest is invalid. $($_.Exception.Message)"
    }
  }
  if ((Compare-PwshProfileSemanticVersion -Left $latestVersion -Right $installedVersion) -le 0) {
    Write-PwshProfileStatus -Stage 'Module' -Type Current -Message "$ModuleName $installedVersion is already up to date."
    return $true
  }

  Write-PwshProfileHeader -Title "$ModuleName Update" -Subtitle 'Verified Independent Module Release'
  Write-PwshProfileStatus -Stage 'Update' -Message "Installed version: $installedVersion"
  Write-PwshProfileStatus -Stage 'Update' -Message "Selected release: $($release.tag_name)"
  if (-not (Test-Path -LiteralPath $moduleRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null
  }
  $releaseAssets = @{}
  foreach ($asset in @($release.assets)) {
    $releaseAssets[[string]$asset.name] = [string]$asset.browser_download_url
  }
  $releaseManifestName = "$ModuleName.release.json"
  if (-not $releaseAssets.ContainsKey($releaseManifestName)) {
    throw "Release $($release.tag_name) does not contain $releaseManifestName."
  }
  $temporaryManifest = Join-Path $moduleRoot ".$releaseManifestName.$PID.tmp"
  try {
    Save-PwshProfileReleaseAsset -Uri $releaseAssets[$releaseManifestName] -Destination $temporaryManifest
    $releaseManifest = Get-Content -LiteralPath $temporaryManifest -Raw | ConvertFrom-Json -ErrorAction Stop
  } finally {
    Remove-Item -LiteralPath $temporaryManifest -Force -ErrorAction SilentlyContinue
  }
  if ($releaseManifest.schemaVersion -ne 1 -or
    [string]$releaseManifest.module -ne $ModuleName -or
    [string]$releaseManifest.version -ne $latestVersion -or
    [string]$releaseManifest.tag -ne [string]$release.tag_name -or
    [string]$releaseManifest.repository -ne $Repository) {
    throw 'The independent module manifest does not match the GitHub Release metadata.'
  }

  $artifactNames = [ordered]@{}
  foreach ($property in $releaseManifest.artifacts.PSObject.Properties) {
    $assetName = [string]$property.Value.asset
    if ($property.Name -notmatch '^[A-Za-z][A-Za-z0-9]*$' -or
      [IO.Path]::GetFileName($assetName) -ne $assetName -or
      $assetName -notmatch "^$([regex]::Escape($ModuleName))(?:\.[A-Za-z0-9.-]+)?\.(?:psd1|psm1|ps1xml)$") {
      throw "The module release contains an invalid artifact '$assetName'."
    }
    $artifactNames[$property.Name] = $assetName
  }
  if (-not $artifactNames.Contains('manifest') -or -not $artifactNames.Contains('script')) {
    throw 'The module release must contain manifest and script artifacts.'
  }
  $baselineStage = $null
  $staged = @{}
  try {
    # Independent updates share the bundle baseline so subsequent bundle updates
    # recognize these files as verified releases, rather than local edits.
    $baselinePath = Join-Path $paths.Root 'version.json'
    $baseline = Get-Content -LiteralPath $baselinePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($baseline.schemaVersion -ne 2 -or -not $baseline.artifacts) {
      throw 'A valid profile baseline is required. Run the Profile setup phase first.'
    }
    $baselineEntries = @{}
    foreach ($entry in $baseline.artifacts.PSObject.Properties) {
      if ([string]$entry.Value.file -like "$ModuleName.*") {
        $baselineEntries[[string]$entry.Value.file] = $entry.Value
        $trackedPath = Join-Path $moduleRoot $entry.Value.file
        if (-not (Test-Path -LiteralPath $trackedPath -PathType Leaf) -or
          (Get-FileHash -LiteralPath $trackedPath -Algorithm SHA256 -ErrorAction Stop).Hash -ine $entry.Value.sha256) {
          throw "Update refused: tracked module file differs from its baseline: $trackedPath"
        }
      }
    }
    foreach ($name in $artifactNames.Keys) {
      $assetName = $artifactNames[$name]
      if (-not $baselineEntries.ContainsKey($assetName)) {
        throw "Module asset '$assetName' has no bundle baseline entry. Install a profile bundle containing it first."
      }
      $artifact = $releaseManifest.artifacts.$name
      $expectedHash = [string]$artifact.sha256
      if ([string]$artifact.asset -ne $assetName -or
        $expectedHash -notmatch '^[a-fA-F0-9]{64}$' -or
        -not $releaseAssets.ContainsKey($assetName)) {
        throw "The module release manifest entry for '$name' is invalid."
      }
      $staged[$name] = Join-Path $moduleRoot ".$assetName.$PID.update"
      Save-PwshProfileReleaseAsset -Uri $releaseAssets[$assetName] -Destination $staged[$name]
      $actualHash = (Get-FileHash -LiteralPath $staged[$name] -Algorithm SHA256).Hash
      if ($actualHash -ine $expectedHash) { throw "SHA-256 verification failed for '$assetName'." }
      Write-PwshProfileStatus -Stage 'Verify' -Type Success -Message "$assetName ($($actualHash.ToLowerInvariant()))"
    }
    Test-PwshProfileScriptFile -Path $staged.script -Label "$ModuleName module"
    $candidateManifest = Import-PowerShellDataFile -LiteralPath $staged.manifest -ErrorAction Stop
    if ([string]$candidateManifest.ModuleVersion -ne $latestVersion) {
      throw "The module manifest does not declare version '$latestVersion'."
    }
    if ([string]$candidateManifest.RootModule -ne $artifactNames.script) {
      throw 'The module release does not contain the declared RootModule.'
    }
    foreach ($formatName in @($candidateManifest.FormatsToProcess | Where-Object { $_ })) {
      if ([string]$formatName -notin @($artifactNames.Values)) {
        throw "The module release does not contain declared format file '$formatName'."
      }
    }
    foreach ($name in @($artifactNames.Keys | Where-Object { $artifactNames[$_] -like '*.ps1xml' })) {
      $null = [xml](Get-Content -LiteralPath $staged[$name] -Raw -ErrorAction Stop)
    }
    foreach ($name in $artifactNames.Keys) {
      $baselineEntries[$artifactNames[$name]].sha256 = [string]$releaseManifest.artifacts.$name.sha256
    }
    $baselineStage = "$baselinePath.$PID.module-update"
    [IO.File]::WriteAllText($baselineStage, ($baseline | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
  } catch {
    foreach ($path in $staged.Values) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
    throw "Module release validation failed; no installed files were changed. $($_.Exception.Message)"
  }

  $wasLoaded = [bool](Get-Module -Name $ModuleName)
  if ($wasLoaded) { Remove-Module -Name $ModuleName -Force -ErrorAction SilentlyContinue }
  $timestamp = [DateTimeOffset]::UtcNow.ToString('yyyyMMddHHmmss') + '.' + [guid]::NewGuid().ToString('N')
  $backups = @{}
  $installed = [System.Collections.Generic.List[string]]::new()
  try {
    foreach ($name in $artifactNames.Keys) {
      $destination = Join-Path $moduleRoot $artifactNames[$name]
      $backup = "$destination.$timestamp.bak"
      Install-PwshProfileAtomicFile -StagedPath $staged[$name] -Destination $destination -BackupPath $backup
      $backups[$name] = $backup
      $installed.Add($name)
      Write-PwshProfileStatus -Stage 'Install' -Type Success -Message "[Updated] $destination"
    }
    # Treat a failed import as an installation failure and restore the old files.
    if ($wasLoaded) { Import-Module -Name $installedManifestPath -Global -Force -ErrorAction Stop }
    if ($baselineStage) {
      Install-PwshProfileAtomicFile -StagedPath $baselineStage -Destination $baselinePath -BackupPath "$baselinePath.$timestamp.bak"
    }
  } catch {
    $installFailure = $_
    $rollbackErrors = @()
    if ($wasLoaded) { Remove-Module -Name $ModuleName -Force -ErrorAction SilentlyContinue }
    foreach ($name in @($installed)) {
      $destination = Join-Path $moduleRoot $artifactNames[$name]
      try {
        if (Test-Path -LiteralPath $backups[$name] -PathType Leaf) {
          Copy-Item -LiteralPath $backups[$name] -Destination $destination -Force -ErrorAction Stop
        } else {
          Remove-Item -LiteralPath $destination -Force -ErrorAction Stop
        }
      } catch { $rollbackErrors += $_.Exception.Message }
    }
    if ($wasLoaded) {
      try { Import-Module -Name $installedManifestPath -Global -Force -ErrorAction Stop }
      catch { $rollbackErrors += "Could not reload previous module: $($_.Exception.Message)" }
    }
    if ($rollbackErrors.Count) {
      throw "Module installation failed: $($installFailure.Exception.Message) Rollback was incomplete: $($rollbackErrors -join '; '). Backups were retained."
    }
    throw "Module installation failed; previous files and loaded state were restored. $($installFailure.Exception.Message)"
  } finally {
    foreach ($path in $staged.Values) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
    if ($baselineStage) { Remove-Item -LiteralPath $baselineStage -Force -ErrorAction SilentlyContinue }
  }
  Write-PwshProfileStatus -Stage 'Complete' -Type Success -Message "Updated $ModuleName to $latestVersion."
  Write-Host ''
  return $true
}

function Invoke-PwshProfileIndependentModuleUpdates {
  [CmdletBinding()]
  param (
    [string] $Repository = 'smoonlee/oh-my-posh-profile',
    [switch] $Prerelease
  )

  try {
    $releases = @(Get-PwshProfileReleasePages `
        -Uri "https://api.github.com/repos/$Repository/releases?per_page=100" `
        -Headers @{ 'User-Agent' = 'pwsh-profile-module-updater' } `
        -TimeoutSec 15 `
        -ErrorAction Stop)
  } catch {
    Write-PwshProfileStatus -Stage 'Module' -Type Warning -Message "Could not query independent module releases. $($_.Exception.Message)"
    return $false
  }

  $moduleNames = @(
    foreach ($release in $releases) {
      if (-not $release.draft -and
        [string]$release.tag_name -match '^(?<moduleName>PwshProfile\.[A-Za-z0-9_.-]+)-v') {
        $Matches.moduleName
      }
    }
  ) | Sort-Object -Unique
  $paths = Get-PwshProfileLocalStorePaths
  $success = $true
  foreach ($moduleName in $moduleNames) {
    $manifestPath = Join-Path $paths.Modules "$moduleName\$moduleName.psd1"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { continue }
    try {
      if (-not (Invoke-PwshProfileModuleUpdate `
            -ModuleName $moduleName `
            -Repository $Repository `
            -Prerelease:$Prerelease `
            -Releases $releases)) {
        $success = $false
      }
    } catch {
      Write-PwshProfileStatus -Stage 'Module' -Type Warning -Message "$moduleName update failed. $($_.Exception.Message)"
      $success = $false
    }
  }
  return $success
}

function Invoke-GitHubConfiguration {
  [CmdletBinding()]
  param ()

  Write-PwshProfileHeader -Title 'Pwsh Profile Installer' -Subtitle 'Pwsh: GitHub Configuration'

  $git = Get-Command git -ErrorAction SilentlyContinue
  $needsGitGuidance = $true
  if (-not $git) {
    Write-PwshProfileStatus -Stage 'GitHub' -Type Warning -Message 'Git was not found; global commit identity could not be configured.'
  } else {
    $gitUserName = ((& $git.Source config --global --get user.name 2>$null) | Out-String).Trim()
    $gitUserEmail = ((& $git.Source config --global --get user.email 2>$null) | Out-String).Trim()
    $needsGitGuidance = -not $gitUserName -or -not $gitUserEmail

    if (-not $gitUserName) {
      Write-PwshProfileStatus -Stage 'GitHub' -Message 'Git uses your first and last name to identify commits.'
      $firstName = (Read-Host -Prompt 'Git first name').Trim()
      $lastName = (Read-Host -Prompt 'Git last name').Trim()
      $gitUserName = "$firstName $lastName".Trim()
      if ($firstName -and $lastName) {
        & $git.Source config --global user.name $gitUserName
        if ($LASTEXITCODE -eq 0) {
          Write-PwshProfileStatus -Stage 'GitHub' -Type Success -Message "Git user.name configured: $gitUserName"
        } else {
          Write-PwshProfileStatus -Stage 'GitHub' -Type Warning -Message 'Git user.name could not be configured.'
        }
      } else {
        Write-PwshProfileStatus -Stage 'GitHub' -Type Warning -Message 'Git user.name skipped; both first and last name are required.'
      }
    } else {
      Write-PwshProfileStatus -Stage 'GitHub' -Type Current -Message "Git user.name: $gitUserName"
    }

    if (-not $gitUserEmail) {
      Write-PwshProfileStatus -Stage 'GitHub' -Message 'Use an email associated with GitHub, or your GitHub no-reply email, for commit attribution.'
      $gitUserEmail = (Read-Host -Prompt 'GitHub email').Trim()
      if ($gitUserEmail -match '^[^\s@]+@[^\s@]+\.[^\s@]+$') {
        & $git.Source config --global user.email $gitUserEmail
        if ($LASTEXITCODE -eq 0) {
          Write-PwshProfileStatus -Stage 'GitHub' -Type Success -Message "Git user.email configured: $gitUserEmail"
        } else {
          Write-PwshProfileStatus -Stage 'GitHub' -Type Warning -Message 'Git user.email could not be configured.'
        }
      } else {
        Write-PwshProfileStatus -Stage 'GitHub' -Type Warning -Message 'Git user.email skipped; enter a valid email address when the installer is run again.'
      }
    } else {
      Write-PwshProfileStatus -Stage 'GitHub' -Type Current -Message "Git user.email: $gitUserEmail"
    }
  }

  Write-Host ''
  if ($needsGitGuidance) {
    Write-PwshProfileStatus -Stage 'GitHub' -Message 'Git name/email control commit attribution; they do not sign in to GitHub.'
    Write-PwshProfileStatus -Stage 'GitHub' -Type Action -Message "GitHub CLI sign-in (if needed): gh auth login"
  }
  Write-PwshProfileStatus -Stage 'Copilot' -Type Action -Message "Authenticate the prompt usage segment: oh-my-posh auth copilot"
  Write-PwshProfileStatus -Stage 'Copilot' -Message 'Oh My Posh opens GitHub device login and securely stores the token for future prompt usage checks.'
  Write-Host ''
}

function Invoke-PwshProfileConfiguration {
  [CmdletBinding()]
  param (
    [switch] $Prerelease,

    [switch] $LocalSource
  )

  $releaseInstalled = Invoke-PwshProfileUpdate `
    -Bootstrap `
    -Prerelease:$Prerelease `
    -LocalSource:$LocalSource
  if (-not $releaseInstalled) {
    Write-PwshProfileStatus -Stage 'Profile' -Type Warning -Message 'Profile configuration stopped because no validated profile source was installed.'
    return
  }
  Invoke-CrossPlatformProfileConfiguration
  Invoke-GitHubConfiguration
  Import-PwshProfileConfiguration
}

function Invoke-PowerShellModuleConfiguration {
  [CmdletBinding()]
  param ()

  Write-PwshProfileHeader -Title 'Pwsh Profile Installer' -Subtitle 'PowerShell Module Configuration'

  $moduleStateRegistryPath = 'HKCU:\Software\smoonlee\OhMyPoshProfile\Modules'
  Initialize-PowerShellGallery
  $modules = @(Get-PowerShellModuleDefinitions)
  Show-PowerShellModuleInventory -Modules $modules
  Write-PwshProfileStatus -Stage 'Modules' -Message "Checking $($modules.Count) module(s)..."

  $summary = [ordered]@{
    Updated = 0
    Current = 0
    Failed  = 0
  }

  foreach ($module in $modules) {
    $result = Invoke-PowerShellModuleAction -Module $module -StateRegistryPath $moduleStateRegistryPath
    if ($summary.Contains($result)) {
      $summary[$result]++
    }
  }

  Write-Host ''
  $summaryType = if ($summary.Failed -gt 0) { 'Warning' } elseif ($summary.Updated -gt 0) { 'Success' } else { 'Current' }
  Write-PwshProfileStatus -Stage 'Modules' -Type $summaryType -Message "Summary: $($summary.Updated) updated, $($summary.Current) current, $($summary.Failed) failed."
}

function Get-CrossPlatformSupportPaths {
  [CmdletBinding()]
  param ()

  $documentsPath = [Environment]::GetFolderPath('MyDocuments')
  $pwsh7Root = Join-Path $documentsPath 'PowerShell'
  $pwsh5Root = Join-Path $documentsPath 'WindowsPowerShell'
  $isPwsh7 = $PSVersionTable.PSVersion.Major -ge 6

  # The host that launched the installer is the source of truth; the other version is linked to it.
  [pscustomobject]@{
    SourceRoot  = if ($isPwsh7) { $pwsh7Root } else { $pwsh5Root }
    TargetRoot  = if ($isPwsh7) { $pwsh5Root } else { $pwsh7Root }
    SourceLabel = if ($isPwsh7) { 'PowerShell 7' } else { 'PowerShell 5.1' }
    TargetLabel = if ($isPwsh7) { 'PowerShell 5.1' } else { 'PowerShell 7' }
    Pwsh7Root   = $pwsh7Root
  }
}

function Set-PwshSymbolicLink {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $Path,

    [Parameter(Mandatory)]
    [string] $Target,

    [ValidateSet('Directory', 'File')]
    [string] $ItemType = 'Directory'
  )

  try {
    if (-not (Test-Path -LiteralPath $Target)) {
      $targetParent = Split-Path -Path $Target -Parent
      if ($targetParent -and -not (Test-Path -LiteralPath $targetParent)) {
        New-Item -ItemType Directory -Path $targetParent -Force -ErrorAction Stop | Out-Null
      }
      New-Item -ItemType $ItemType -Path $Target -Force -ErrorAction Stop | Out-Null
      Write-PwshProfileStatus -Stage 'Profile' -Type Action -Message "Created missing target '$Target'."
    }

    $existingItem = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($existingItem) {
      if ($existingItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $existingTarget = @($existingItem.Target) | Select-Object -First 1
        if ($existingTarget -and $existingTarget.TrimEnd('\') -ieq $Target.TrimEnd('\')) {
          Write-PwshProfileStatus -Stage 'Profile' -Type Current -Message "'$Path' already linked to '$Target'."
          return $true
        }
        Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
      } elseif ($existingItem.PSIsContainer) {
        if (@(Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue).Count -gt 0) {
          Write-PwshProfileStatus -Stage 'Profile' -Type Warning -Message "'$Path' has existing content; move it into '$Target' and rerun to link safely."
          return $false
        }
        Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
      } else {
        Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
      }
    }

    $pathParent = Split-Path -Path $Path -Parent
    if ($pathParent -and -not (Test-Path -LiteralPath $pathParent)) {
      New-Item -ItemType Directory -Path $pathParent -Force -ErrorAction Stop | Out-Null
    }

    New-Item -ItemType SymbolicLink -Path $Path -Target $Target -Force -ErrorAction Stop | Out-Null
    Write-PwshProfileStatus -Stage 'Profile' -Type Success -Message "Linked '$Path' -> '$Target'."
    return $true
  } catch {
    Write-PwshProfileStatus -Stage 'Profile' -Type Warning -Message "Failed to link '$Path' -> '$Target': $($_.Exception.Message) (creating symbolic links requires Administrator or Developer Mode)."
    return $false
  }
}

function Set-PwshExecutionPolicy {
  [CmdletBinding()]
  param ()

  try {
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
    if ($currentPolicy -in @('RemoteSigned', 'Unrestricted', 'Bypass')) {
      Write-PwshProfileStatus -Stage 'Profile' -Type Current -Message "Execution policy already $currentPolicy for $($PSVersionTable.PSEdition) [CurrentUser]."
    } else {
      Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
      Write-PwshProfileStatus -Stage 'Profile' -Type Success -Message "Execution policy set to RemoteSigned for $($PSVersionTable.PSEdition) [CurrentUser]."
    }
  } catch {
    Write-PwshProfileStatus -Stage 'Profile' -Type Warning -Message "Could not set execution policy for $($PSVersionTable.PSEdition): $($_.Exception.Message)"
  }

  # A linked profile is useless to the *other* PowerShell version if its execution policy still blocks scripts,
  # so set RemoteSigned there too by shelling out to that version's own executable.
  $otherExecutable = if ($PSVersionTable.PSEdition -eq 'Core') {
    Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  } else {
    (Get-Command pwsh -ErrorAction SilentlyContinue).Source
  }

  if (-not $otherExecutable -or -not (Test-Path -LiteralPath $otherExecutable)) {
    return
  }

  try {
    $otherExecutableName = Split-Path -Path $otherExecutable -Leaf
    $otherPolicyOutput = & $otherExecutable -NoProfile -Command 'Get-ExecutionPolicy -Scope CurrentUser' 2>$null
    $otherPolicyExitCode = $LASTEXITCODE
    $otherPolicy = @($otherPolicyOutput) | Select-Object -First 1
    if ($otherPolicyExitCode -ne 0 -or -not $otherPolicy) {
      Write-PwshProfileStatus -Stage 'Profile' -Type Warning -Message "Could not read execution policy via $otherExecutableName (exit $otherPolicyExitCode)."
      return
    }

    if ([string]$otherPolicy -in @('RemoteSigned', 'Unrestricted', 'Bypass')) {
      Write-PwshProfileStatus -Stage 'Profile' -Type Current -Message "Execution policy already $otherPolicy for $otherExecutableName [CurrentUser]."
      return
    }

    & $otherExecutable -NoProfile -Command 'Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force' 2>$null
    if ($LASTEXITCODE -eq 0) {
      Write-PwshProfileStatus -Stage 'Profile' -Type Success -Message "Execution policy set to RemoteSigned for $otherExecutableName [CurrentUser]."
    } else {
      Write-PwshProfileStatus -Stage 'Profile' -Type Warning -Message "Could not set execution policy via $otherExecutableName (exit $LASTEXITCODE)."
    }
  } catch {
    Write-PwshProfileStatus -Stage 'Profile' -Type Warning -Message "Could not set execution policy via '$otherExecutable': $($_.Exception.Message)"
  }
}

function Invoke-CrossPlatformProfileConfiguration {
  [CmdletBinding()]
  param ()

  Write-PwshProfileHeader -Title 'Pwsh Profile Installer' -Subtitle 'Cross-Platform Module & Profile Support'

  Set-PwshExecutionPolicy

  try {
    $paths = Get-CrossPlatformSupportPaths
    Write-Host ''
    Write-PwshProfileStatus -Stage 'Profile' -Message "Running $($paths.SourceLabel); linking $($paths.TargetLabel) to match."

    if (-not (Test-Path -LiteralPath $paths.SourceRoot)) {
      New-Item -ItemType Directory -Path $paths.SourceRoot -Force -ErrorAction Stop | Out-Null
    }

    $linkResults = @(
      Set-PwshSymbolicLink -ItemType Directory `
        -Path (Join-Path $paths.TargetRoot 'Modules') `
        -Target (Join-Path $paths.SourceRoot 'Modules')

      Set-PwshSymbolicLink -ItemType File `
        -Path (Join-Path $paths.TargetRoot 'Microsoft.PowerShell_profile.ps1') `
        -Target (Join-Path $paths.SourceRoot 'Microsoft.PowerShell_profile.ps1')

      Set-PwshSymbolicLink -ItemType File `
        -Path (Join-Path $paths.Pwsh7Root 'Microsoft.VSCode_profile.ps1') `
        -Target (Join-Path $paths.SourceRoot 'Microsoft.PowerShell_profile.ps1')
    )

    if ($linkResults -contains $false) {
      Write-PwshProfileStatus -Stage 'Profile' -Type Warning -Message 'Cross-platform support is only partially configured; resolve the link warnings above and rerun the Profile phase.'
    } else {
      Write-PwshProfileStatus -Stage 'Profile' -Type Success -Message 'Cross-platform module and profile support configured.'
    }
  } catch {
    Write-PwshProfileStatus -Stage 'Profile' -Type Warning -Message "Cross-platform support failed: $($_.Exception.Message)"
  }
}

function Get-PwshProfileResetTargets {
  [CmdletBinding()]
  param (
    [string] $DocumentsPath = [Environment]::GetFolderPath('MyDocuments'),

    [string] $AppDataPath = $env:APPDATA,

    [string] $LocalAppDataPath = $env:LOCALAPPDATA,

    [string] $ProgramFilesPath = $env:ProgramFiles,

    [string] $ProgramFilesX86Path = ${env:ProgramFiles(x86)},

    [string] $StateRegistryPath = 'HKCU:\Software\smoonlee\OhMyPoshProfile'
  )

  $legacyThemePaths = @(
    if ($env:POSH_THEMES_PATH) {
      Join-Path $env:POSH_THEMES_PATH 'quick-term-cloud.omp.json'
    }
    if ($LocalAppDataPath) {
      Join-Path $LocalAppDataPath 'Programs\oh-my-posh\themes\quick-term-cloud.omp.json'
    }
    if ($ProgramFilesPath) {
      Join-Path $ProgramFilesPath 'oh-my-posh\themes\quick-term-cloud.omp.json'
    }
    if ($ProgramFilesX86Path) {
      Join-Path $ProgramFilesX86Path 'oh-my-posh\themes\quick-term-cloud.omp.json'
    }
  ) | Select-Object -Unique
  $stalePowerShellRoots = @(
    Get-ChildItem -LiteralPath $DocumentsPath -Directory -Force -ErrorAction SilentlyContinue |
    Where-Object {
      $_.Name -like 'PowerShell.reset-*' -or
      $_.Name -like 'WindowsPowerShell.reset-*'
    } |
    Select-Object -ExpandProperty FullName
  )

  [pscustomobject]@{
    PowerShellRoots      = @(
      Join-Path $DocumentsPath 'PowerShell'
      Join-Path $DocumentsPath 'WindowsPowerShell'
    )
    StalePowerShellRoots = $stalePowerShellRoots
    LocalStore           = Join-Path $AppDataPath 'PwshProfile'
    LegacyThemes         = @($legacyThemePaths)
    StateRegistry        = $StateRegistryPath
  }
}

function Start-PwshProfileReplacementSession {
  [CmdletBinding()]
  param (
    [AllowEmptyCollection()]
    [string[]] $DeferredPaths = @(),

    [int] $ParentProcessId = $PID,

    [bool] $StayOpen = $true,

    [ValidateRange(1, 100)]
    [int] $CleanupAttempts = 40,

    [ValidateRange(0, 5000)]
    [int] $CleanupDelayMilliseconds = 250
  )

  $powerShellExecutable = if ($PSVersionTable.PSEdition -eq 'Core') {
    Join-Path $PSHOME 'pwsh.exe'
  } else {
    Join-Path $PSHOME 'powershell.exe'
  }
  if (-not (Test-Path -LiteralPath $powerShellExecutable -PathType Leaf)) {
    throw "PowerShell executable was not found: $powerShellExecutable"
  }

  $deferredFullPaths = @(
    $DeferredPaths |
    Where-Object { $_ } |
    ForEach-Object { [System.IO.Path]::GetFullPath($_).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) }
  )
  $pathSeparator = [System.IO.Path]::PathSeparator
  $originalPSModulePath = $env:PSModulePath
  $replacementPSModulePath = @(
    [string]$originalPSModulePath -split [regex]::Escape([string]$pathSeparator) |
    Where-Object { $_ } |
    Where-Object {
      $modulePath = [System.IO.Path]::GetFullPath($_).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
      -not @($deferredFullPaths | Where-Object {
          $modulePath.Equals($_, [System.StringComparison]::OrdinalIgnoreCase) -or
          $modulePath.StartsWith("$_$([System.IO.Path]::DirectorySeparatorChar)", [System.StringComparison]::OrdinalIgnoreCase) -or
          $modulePath.StartsWith("$_$([System.IO.Path]::AltDirectorySeparatorChar)", [System.StringComparison]::OrdinalIgnoreCase)
        }).Count
    }
  ) -join $pathSeparator

  $pathsJson = ConvertTo-Json -InputObject @($DeferredPaths) -Compress
  $replacementPSModulePathEscaped = $replacementPSModulePath.Replace("'", "''")
  $replacementScript = @"
`$env:PSModulePath = '$replacementPSModulePathEscaped'
Remove-Module -Name PSReadLine -Force -ErrorAction SilentlyContinue
`$paths = @(ConvertFrom-Json -InputObject '$($pathsJson.Replace("'", "''"))')
Wait-Process -Id $ParentProcessId -ErrorAction SilentlyContinue
`$failedPaths = @()
foreach (`$path in @(`$paths)) {
  `$removed = `$false
  for (`$attempt = 1; `$attempt -le $CleanupAttempts; `$attempt++) {
    try {
      Remove-Item -LiteralPath `$path -Recurse -Force -Confirm:`$false -ErrorAction Stop
      `$removed = `$true
      break
    } catch {
      if (-not (Test-Path -LiteralPath `$path)) {
        `$removed = `$true
        break
      }
      if (`$attempt -lt $CleanupAttempts) {
        [Threading.Thread]::Sleep($CleanupDelayMilliseconds)
      }
    }
  }
  if (-not `$removed) {
    `$failedPaths += `$path
  }
}
if (`$paths.Count -gt 0 -and `$failedPaths.Count -eq 0) {
  Write-Host '[Reset   ] In-use PowerShell files removed.' -ForegroundColor Green
} elseif (`$failedPaths.Count -gt 0) {
  Write-Host "[WARNING ] Could not remove: `$(`$failedPaths -join ', ')" -ForegroundColor Yellow
}
"@
  $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($replacementScript))
  $arguments = @(
    '-NoLogo'
    '-NoProfile'
    if ($StayOpen) { '-NoExit' }
    '-EncodedCommand'
    $encodedCommand
  )

  try {
    $env:PSModulePath = $replacementPSModulePath
    Start-Process -FilePath $powerShellExecutable -ArgumentList $arguments -NoNewWindow -PassThru -ErrorAction Stop
  } finally {
    $env:PSModulePath = $originalPSModulePath
  }
}

function Test-PwshProfileSymbolicLink {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object] $Item
  )

  $Item.PSProvider.Name -eq 'FileSystem' -and [bool]$Item.LinkType
}

function Remove-PwshProfileResetItem {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $Path,

    [Parameter(Mandatory)]
    [string] $Label,

    [AllowNull()]
    [System.Collections.Generic.List[string]] $DeferredPaths
  )

  $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
  if (-not $item) {
    Write-PwshProfileStatus -Stage 'Reset' -Type Current -Message "$Label not found: $Path"
    return 'Absent'
  }

  try {
    if (Test-PwshProfileSymbolicLink -Item $item) {
      if ($item.PSIsContainer) {
        [IO.Directory]::Delete($item.FullName, $false)
      } else {
        [IO.File]::Delete($item.FullName)
      }
    } elseif ($item.PSIsContainer) {
      Remove-Item -LiteralPath $Path -Recurse -Force -Confirm:$false -ErrorAction Stop
    } else {
      Remove-Item -LiteralPath $Path -Force -Confirm:$false -ErrorAction Stop
    }
    Write-PwshProfileStatus -Stage 'Reset' -Type Success -Message "$Label removed: $Path"
    'Removed'
  } catch {
    if ($null -ne $DeferredPaths -and $item.PSProvider.Name -eq 'FileSystem' -and $item.PSIsContainer -and
      -not (Test-PwshProfileSymbolicLink -Item $item)) {
      $DeferredPaths.Add($Path)
      Write-PwshProfileStatus -Stage 'Reset' -Type Warning -Message "$Label contains files in use; scheduled for removal during the automatic PowerShell restart: $Path"
      return 'Deferred'
    }

    Write-PwshProfileStatus -Stage 'Reset' -Type Warning -Message "Could not remove $Label '$Path': $($_.Exception.Message)"
    'Failed'
  }
}

function Invoke-PwshProfileModuleUnload {
  [CmdletBinding()]
  param (
    [AllowEmptyCollection()]
    [object[]] $Modules = @(Get-Module),

    [ValidateSet('BeforeCleanup', 'Final')]
    [string] $Phase = 'BeforeCleanup'
  )

  $preservedModuleNames = @('PSReadLine', 'PowerShellGet', 'PackageManagement')
  $modulesToUnload = @(
    $Modules |
    Where-Object { $_.Name -notin $preservedModuleNames } |
    Where-Object {
      if ($Phase -eq 'BeforeCleanup') {
        $_.Name -notlike 'Microsoft.PowerShell.*'
      } else {
        $_.Name -like 'Microsoft.PowerShell.*'
      }
    } |
    Sort-Object Name, Version -Descending
  )

  if ($Phase -eq 'BeforeCleanup') {
    foreach ($preservedModule in @($Modules | Where-Object { $_.Name -in $preservedModuleNames })) {
      Write-PwshProfileStatus -Stage 'Modules' -Type Current -Message "Preserved module: $($preservedModule.Name) $($preservedModule.Version)"
    }
  }

  if ($modulesToUnload.Count -eq 0) {
    if ($Phase -eq 'BeforeCleanup') {
      Write-PwshProfileStatus -Stage 'Modules' -Type Current -Message 'No loaded user modules require unloading.'
    }
    return
  }

  if ($Phase -eq 'BeforeCleanup') {
    foreach ($module in $modulesToUnload) {
      try {
        Remove-Module -ModuleInfo $module -Force -ErrorAction Stop
        Write-PwshProfileStatus -Stage 'Modules' -Type Success -Message "Unloaded module: $($module.Name) $($module.Version)"
      } catch {
        Write-PwshProfileStatus -Stage 'Modules' -Type Warning -Message "Could not unload module '$($module.Name)' $($module.Version): $($_.Exception.Message)"
      }
    }
    return
  }

  # Keep this as the final reset operation: unloading foundational modules can remove
  # commands such as Write-Host and Get-Module from the current session.
  Remove-Module -ModuleInfo $modulesToUnload -Force -ErrorAction SilentlyContinue
}

function Invoke-PwshProfileReset {
  [CmdletBinding()]
  param (
    [switch] $SkipConfirmation,

    [switch] $SkipSessionRestart,

    [object] $Targets = (Get-PwshProfileResetTargets),

    [AllowNull()]
    [object[]] $LoadedModules
  )

  Write-PwshProfileHeader -Title 'Pwsh Profile Installer' -Subtitle 'DESTRUCTIVE Profile Reset'
  Write-PwshProfileStatus -Stage 'WARNING' -Type Danger -Message 'RESET WILL PERMANENTLY DELETE BOTH USER POWERSHELL CONFIGURATION FOLDERS.'
  Write-PwshProfileStatus -Stage 'WARNING' -Type Danger -Message 'ALL user-installed PowerShell modules, profiles, profile backups, and symbolic links in those folders will be removed.'
  Write-PwshProfileStatus -Stage 'WARNING' -Type Danger -Message 'All loaded modules except PSReadLine, PowerShellGet, and PackageManagement will be unloaded from this session.'
  Write-PwshProfileStatus -Stage 'WARNING' -Type Danger -Message 'The local PwshProfile store, installer state, and legacy quick-term-cloud theme copies will also be removed.'
  Write-Host ''
  Write-PwshProfileStatus -Stage 'Backup' -Type Warning -Message 'Take a backup of anything you need before continuing.'
  Write-Host ''
  Write-PwshProfileStatus -Stage 'Retained' -Type Current -Message 'Oh My Posh, Winget applications, Windows Terminal settings, and system-wide PowerShell modules will not be uninstalled.'
  Write-PwshProfileStatus -Stage 'Session' -Type Current -Message 'PowerShell will restart automatically in this terminal window when reset is complete.'

  if (-not $SkipConfirmation) {
    Write-Host ''
    Write-PwshProfileStatus -Stage 'Confirm' -Type Action -Message 'Press any key to start the reset, or press Ctrl+C to cancel.'
    try {
      $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    } catch {
      $confirmation = Read-Host -Prompt "Raw key input is unavailable. Type RESET to continue"
      if ($confirmation -cne 'RESET') {
        Write-PwshProfileStatus -Stage 'Reset' -Type Warning -Message 'Reset cancelled.'
        return
      }
    }
  }

  Write-Host ''
  $loadedModules = if ($PSBoundParameters.ContainsKey('LoadedModules')) {
    @($LoadedModules)
  } else {
    @(Get-Module)
  }
  Write-PwshProfileStatus -Stage 'Modules' -Type Action -Message 'Unloading user modules before removing their files...'
  Invoke-PwshProfileModuleUnload -Modules $loadedModules -Phase BeforeCleanup

  Write-Host ''
  Write-PwshProfileStatus -Stage 'Reset' -Type Action -Message 'Removing PowerShell profile and module artifacts...'
  $results = [System.Collections.Generic.List[string]]::new()
  $deferredPaths = [System.Collections.Generic.List[string]]::new()

  # Remove links first so neither PowerShell directory can lead into the other while deleting.
  $powerShellRootItems = @(
    foreach ($root in @($Targets.PowerShellRoots)) {
      [pscustomobject]@{
        Path = $root
        Item = Get-Item -LiteralPath $root -Force -ErrorAction SilentlyContinue
      }
    }
  )
  foreach ($target in @($powerShellRootItems | Where-Object { $_.Item -and (Test-PwshProfileSymbolicLink -Item $_.Item) })) {
    $results.Add((Remove-PwshProfileResetItem -Path $target.Path -Label 'PowerShell link' -DeferredPaths $deferredPaths))
  }
  foreach ($target in @($powerShellRootItems | Where-Object { -not $_.Item -or -not (Test-PwshProfileSymbolicLink -Item $_.Item) })) {
    $results.Add((Remove-PwshProfileResetItem -Path $target.Path -Label 'PowerShell configuration' -DeferredPaths $deferredPaths))
  }
  foreach ($stalePowerShellRoot in @($Targets.StalePowerShellRoots)) {
    $results.Add((Remove-PwshProfileResetItem -Path $stalePowerShellRoot -Label 'Previous reset folder' -DeferredPaths $deferredPaths))
  }

  $results.Add((Remove-PwshProfileResetItem -Path $Targets.LocalStore -Label 'Local profile store' -DeferredPaths $deferredPaths))
  foreach ($legacyThemePath in @($Targets.LegacyThemes)) {
    $results.Add((Remove-PwshProfileResetItem -Path $legacyThemePath -Label 'Legacy Oh My Posh theme' -DeferredPaths $deferredPaths))
  }
  $results.Add((Remove-PwshProfileResetItem -Path $Targets.StateRegistry -Label 'Installer registry state' -DeferredPaths $deferredPaths))

  $removedCount = @($results | Where-Object { $_ -eq 'Removed' }).Count
  $deferredCount = @($results | Where-Object { $_ -eq 'Deferred' }).Count
  $absentCount = @($results | Where-Object { $_ -eq 'Absent' }).Count
  $failedCount = @($results | Where-Object { $_ -eq 'Failed' }).Count
  $summaryType = if ($failedCount -gt 0 -or $deferredCount -gt 0) { 'Warning' } else { 'Success' }
  Write-PwshProfileStatus -Stage 'Complete' -Type $summaryType -Message "Reset complete: $removedCount removed, $deferredCount pending session restart, $absentCount already absent, $failedCount failed."

  $replacementStarted = $false
  if ($SkipSessionRestart) {
    Write-PwshProfileStatus -Stage 'Next' -Type Action -Message 'Close PowerShell to release any in-use files, then open a new session.'
  } else {
    try {
      Write-PwshProfileStatus -Stage 'Session' -Type Action -Message 'Restarting PowerShell in this terminal window...'
      Start-PwshProfileReplacementSession -DeferredPaths $deferredPaths.ToArray() | Out-Null
      $replacementStarted = $true
    } catch {
      Write-PwshProfileStatus -Stage 'Session' -Type Warning -Message "Automatic session restart failed: $($_.Exception.Message)"
      Write-PwshProfileStatus -Stage 'Next' -Type Action -Message 'Close PowerShell to release any in-use files, then open a new session.'
    }
  }

  Invoke-PwshProfileModuleUnload -Modules $loadedModules -Phase Final
  if ($replacementStarted) {
    [Environment]::Exit(0)
  }
}

if ($Reset) {
  Invoke-PwshProfileReset
  return
}

if ($LocalSource -and -not $PSBoundParameters.ContainsKey('RunPhase')) {
  $RunPhase = 'Profile'
}

if ($LocalSource -and $Prerelease) {
  throw '-LocalSource and -Prerelease cannot be used together.'
}

if ($LocalSource -and $RunPhase -notin @('All', 'NerdFont', 'Profile', 'ProfileUpdate')) {
  throw '-LocalSource is supported only with -RunPhase All, NerdFont, Profile, or ProfileUpdate.'
}

if (-not $nerdFontName -and $RunPhase -in @('All', 'NerdFont')) {
  throw "NerdFontName is required for the All and NerdFont phases unless -Reset is specified. Run 'Get-Help $PSCommandPath -Detailed' for usage."
}

if ($RunPhase -in @('All', 'NerdFont') -and $nerdFontName) {
  Write-PwshProfileHeader -Title 'Pwsh Profile Installer' -Subtitle 'Nerd Font Configuration'

  $nerdFontStateRegistryPath = 'HKCU:\Software\smoonlee\OhMyPoshProfile\NerdFonts'
  try {
    $catalogSource = Get-PwshProfileNerdFontsCatalogSource -Prerelease:$Prerelease -LocalSource:$LocalSource -SourceRoot $PSScriptRoot
  } catch {
    Write-PwshProfileStatus -Stage 'Catalog' -Type Danger -Message $_.Exception.Message
    Write-Host ''
    exit 1
  }
  Write-PwshProfileStatus -Stage 'Catalog' -Message "Using verified asset from $($catalogSource.ReleaseTag)."
  $nerdFontsCatalog = if ($LocalSource) {
    Get-NerdFontsCatalog -LocalPath $catalogSource.LocalPath
  } else {
    Get-NerdFontsCatalog -RemoteUri $catalogSource.Uri -ExpectedSha256 $catalogSource.Sha256
  }
  $selectedNerdFont = Resolve-NerdFont -Catalog $nerdFontsCatalog -Name $nerdFontName

  # Download archives use ArchiveName.zip; keep the validated friendly name intact.
  $nerdFontArchiveName = $selectedNerdFont.ArchiveName
  $nerdFontVersion = $selectedNerdFont.FontVersion
  $nerdFontsVersion = $nerdFontsCatalog.NerdFontsVersion
  Write-PwshProfileStatus -Stage 'Font' -Message "Selected $nerdFontName (archive: $nerdFontArchiveName; font: $nerdFontVersion)."

  $windowsFontDirectories = @(Get-WindowsFontDirectories)
  Write-PwshProfileStatus -Stage 'Check' -Message "Searching $($windowsFontDirectories.Count) Windows font location(s)..."
  $installedNerdFontFiles = @(
    Find-InstalledNerdFont -Font $selectedNerdFont -FontDirectories $windowsFontDirectories
  )
  $nerdFontInstalled = $installedNerdFontFiles.Count -gt 0
  $installState = Get-NerdFontInstallState -RegistryPath $nerdFontStateRegistryPath -ArchiveName $nerdFontArchiveName
  $installDecision = Get-NerdFontInstallDecision `
    -IsInstalled $nerdFontInstalled `
    -InstallState $installState `
    -LatestNerdFontsVersion $nerdFontsVersion `
    -LatestFontVersion ([string]$nerdFontVersion)
  $installedNerdFontsVersion = $installDecision.InstalledVersion

  if ($installDecision.IsNewerThanCatalog) {
    Write-PwshProfileStatus -Stage 'Version' -Type Warning -Message "Installed $installedNerdFontsVersion is newer than catalog $nerdFontsVersion; downgrade skipped."
  }

  if (-not $installDecision.RequiresInstall) {
    Write-Host ''
    if ($installDecision.IsUntracked) {
      Write-PwshProfileStatus -Stage 'Found' -Type Warning -Message "$nerdFontName is installed; release unknown, so it was left unchanged."
    } else {
      Write-PwshProfileStatus -Stage 'Current' -Type Current -Message "$nerdFontName at Nerd Fonts $installedNerdFontsVersion."
    }
    $installedNerdFontFiles | ForEach-Object {
      Write-PwshProfileStatus -Stage 'File' -Message $_.FullName
    }
    if ($installedNerdFontFiles.Count -gt 0) {
      Update-WindowsTerminalFromNerdFontFiles -FontFiles $installedNerdFontFiles
    }
  } else {
    Write-PwshProfileStatus -Stage 'Action' -Type Action -Message "$nerdFontName requires installation: $($installDecision.Reason)."
    if (-not (Test-PwshProfileAdministrator)) {
      Start-PwshProfileElevated `
        -ScriptPath $PSCommandPath `
        -NerdFontName $nerdFontName `
        -Prerelease:$Prerelease `
        -LocalSource:$LocalSource
      $installedNerdFontFiles = @(
        Find-InstalledNerdFont -Font $selectedNerdFont -FontDirectories $windowsFontDirectories
      )
      Update-WindowsTerminalFromNerdFontFiles -FontFiles $installedNerdFontFiles -PostInstall
      if ($RunPhase -eq 'NerdFont') {
        return
      }
    } else {
      $newlyInstalledFontFiles = @(
        Install-NerdFont `
          -Font $selectedNerdFont `
          -NerdFontsVersion $nerdFontsVersion `
          -ExistingFiles $installedNerdFontFiles `
          -StateRegistryPath $nerdFontStateRegistryPath
      )

      Update-WindowsTerminalFromNerdFontFiles -FontFiles $newlyInstalledFontFiles -PostInstall

      Write-PwshProfileStatus -Stage 'Complete' -Type Success -Message "$nerdFontName installed at Nerd Fonts $nerdFontsVersion."
    }
  }
}

if ($RunPhase -in @('All', 'Winget')) {
  Invoke-WingetConfiguration
}

if ($RunPhase -in @('All', 'Modules')) {
  Invoke-PowerShellModuleConfiguration
}

if ($RunPhase -in @('All', 'Profile')) {
  Invoke-PwshProfileConfiguration -Prerelease:$Prerelease -LocalSource:$LocalSource
}

if ($RunPhase -eq 'ProfileUpdate') {
  [void](Invoke-PwshProfileUpdate -Prerelease:$Prerelease -LocalSource:$LocalSource)
  if (-not $LocalSource) {
    [void](Invoke-PwshProfileIndependentModuleUpdates -Prerelease:$Prerelease)
  }
}
