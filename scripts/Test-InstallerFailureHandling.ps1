$ErrorActionPreference = 'Stop'
$setupPath = Join-Path $PSScriptRoot '../src/Invoke-PwshProfileSetup.ps1'
$tokens = $null
$parseErrors = $null
$setupAst = [System.Management.Automation.Language.Parser]::ParseFile($setupPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }

foreach ($functionName in @('Install-NerdFont', 'Remove-NerdFontRegistration', 'Set-NerdFontInstallState', 'Invoke-PwshProfileConfiguration', 'ConvertTo-NerdFontsReleaseVersion')) {
    $definition = $setupAst.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $functionName
        }, $true)
    if (-not $definition) { throw "Function not found: $functionName" }
    . ([scriptblock]::Create($definition.Extent.Text))
}

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('installer-failure-' + [guid]::NewGuid().ToString('N'))
$originalTemp = $env:TEMP
$originalWindows = $env:WINDIR
$null = New-Item -ItemType Directory -Path $testRoot -Force
try {
    $env:TEMP = Join-Path $testRoot 'temp'
    $env:WINDIR = Join-Path $testRoot 'windows'
    $systemFontDirectory = Join-Path $env:WINDIR 'Fonts'
    $oldFontDirectory = Join-Path $testRoot 'user-fonts'
    $null = New-Item -ItemType Directory -Path $systemFontDirectory, $oldFontDirectory, $env:TEMP -Force

    $oldFontPath = Join-Path $oldFontDirectory 'OldFontNerdFont-Regular.ttf'
    [System.IO.File]::WriteAllText($oldFontPath, 'old font bytes')
    $script:InstallSources = [System.Collections.Generic.List[string]]::new()
    $script:InstallFiles = @(
        foreach ($name in @('NewFontNerdFont-Regular.ttf', 'NewFontNerdFont-Bold.ttf')) {
            $path = Join-Path $testRoot $name
            [System.IO.File]::WriteAllText($path, "new bytes: $name")
            $script:InstallSources.Add([System.IO.Path]::GetFullPath($path))
            Get-Item -LiteralPath $path
        }
    )
    $script:FakeRegistry = @{}
    $fontRegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    $stateRegistryPath = 'HKCU:\Software\Test\FontState'
    $script:FakeRegistry[$fontRegistryPath] = @{ 'Old Font (TrueType)' = 'OldFontNerdFont-Regular.ttf' }
    $script:FakeRegistry[$stateRegistryPath] = @{ TestFont = 'previous-state' }
    $script:FailNotificationOnce = $true
    $script:FailRestorePath = $null
    $script:FailInstallSource = $null
    $script:BlockOverwritePath = $null

    function Test-PwshProfileAdministrator { $true }
    function Write-PwshProfileStatus { param($Stage, $Type, $Message) }
    function Invoke-WebRequest {
        [CmdletBinding()]
        param([uri] $Uri, [string] $OutFile, [switch] $UseBasicParsing)
        [System.IO.File]::WriteAllText($OutFile, 'synthetic archive')
    }
    function Expand-Archive {
        [CmdletBinding()]
        param([string] $LiteralPath, [string] $DestinationPath, [switch] $Force)
    }
    function Select-NerdFontInstallFiles { param($Font, $ExtractPath) $script:InstallFiles }
    function Send-WindowsFontChange {
        if ($script:FailNotificationOnce) {
            $script:FailNotificationOnce = $false
            throw 'Synthetic notification failure'
        }
    }
    function Test-Path {
        [CmdletBinding()]
        param([string] $LiteralPath, [ValidateSet('Any', 'Container', 'Leaf')][string] $PathType = 'Any')
        if ($LiteralPath -like 'HKCU:\*' -or $LiteralPath -like 'HKLM:\*') {
            return $script:FakeRegistry.ContainsKey($LiteralPath)
        }
        if ($PathType -eq 'Any') {
            Microsoft.PowerShell.Management\Test-Path -LiteralPath $LiteralPath
        } else {
            Microsoft.PowerShell.Management\Test-Path -LiteralPath $LiteralPath -PathType $PathType
        }
    }
    function Get-ItemProperty {
        [CmdletBinding()]
        param([string] $LiteralPath)
        if (-not $script:FakeRegistry.ContainsKey($LiteralPath)) {
            throw "Synthetic registry key not found: $LiteralPath"
        }
        $result = [pscustomobject]@{}
        foreach ($name in $script:FakeRegistry[$LiteralPath].Keys) {
            $result | Add-Member -MemberType NoteProperty -Name $name -Value $script:FakeRegistry[$LiteralPath][$name]
        }
        $result
    }
    function New-ItemProperty {
        [CmdletBinding()]
        param([string] $LiteralPath, [string] $Name, [object] $Value, [string] $PropertyType, [switch] $Force)
        if (-not $script:FakeRegistry.ContainsKey($LiteralPath)) { $script:FakeRegistry[$LiteralPath] = @{} }
        $script:FakeRegistry[$LiteralPath][$Name] = $Value
    }
    function Remove-ItemProperty {
        [CmdletBinding()]
        param([string] $LiteralPath, [string] $Name)
        if ($script:FakeRegistry.ContainsKey($LiteralPath)) {
            if (-not $script:FakeRegistry[$LiteralPath].ContainsKey($Name)) {
                throw "Synthetic registry value not found: $LiteralPath\$Name"
            }
            $script:FakeRegistry[$LiteralPath].Remove($Name)
        }
    }
    function New-Item {
        [CmdletBinding()]
        param([string] $Path, [string] $ItemType, [switch] $Force)
        if ($Path -like 'HKCU:\*' -or $Path -like 'HKLM:\*') {
            if (-not $script:FakeRegistry.ContainsKey($Path)) { $script:FakeRegistry[$Path] = @{} }
            return
        }
        Microsoft.PowerShell.Management\New-Item @PSBoundParameters
    }
    function Copy-Item {
        [CmdletBinding()]
        param([string] $LiteralPath, [string] $Destination, [switch] $Force)
        if ($script:BlockOverwritePath -and
            $script:InstallSources.Contains([System.IO.Path]::GetFullPath($LiteralPath)) -and
            [System.IO.Path]::GetFullPath($Destination) -ieq $script:BlockOverwritePath -and
            (Test-Path -LiteralPath $Destination -PathType Leaf)) {
            throw 'Synthetic font file in use'
        }
        if ($script:FailInstallSource -and
            [System.IO.Path]::GetFullPath($LiteralPath) -ieq $script:FailInstallSource) {
            $script:FailInstallSource = $null
            throw 'Synthetic font copy failure'
        }
        if ($script:FailRestorePath -and
            [System.IO.Path]::GetFullPath($Destination) -ieq $script:FailRestorePath -and
            -not $script:InstallSources.Contains([System.IO.Path]::GetFullPath($LiteralPath))) {
            $script:FailRestorePath = $null
            throw 'Synthetic backup restoration failure'
        }
        if ($script:InstallSources.Contains([System.IO.Path]::GetFullPath($LiteralPath))) {
            Microsoft.PowerShell.Management\Copy-Item @PSBoundParameters
            return
        }
        Microsoft.PowerShell.Management\Copy-Item @PSBoundParameters
    }
    function Remove-Item {
        [CmdletBinding(SupportsShouldProcess)]
        param([string] $LiteralPath, [switch] $Recurse, [switch] $Force)
        Microsoft.PowerShell.Management\Remove-Item @PSBoundParameters
    }

    $font = [pscustomobject]@{
        ArchiveName  = 'TestFont'
        FriendlyName = 'Test Font'
        DownloadUrl  = 'https://example.invalid/font.zip'
        FontVersion  = '2.0.0'
    }
    $existingFiles = @(Get-Item -LiteralPath $oldFontPath)
    $installFailure = $null
    try {
        $null = Install-NerdFont -Font $font -NerdFontsVersion '4.0.0' -ExistingFiles $existingFiles -StateRegistryPath $stateRegistryPath
    } catch {
        $installFailure = $_
    }
    if (-not $installFailure -or $installFailure.Exception.Message -notlike '*previous font files and registry state were restored*') {
        throw "Expected a recoverable synthetic install failure; got: $($installFailure.Exception.Message)"
    }
    if ([System.IO.File]::ReadAllText($oldFontPath) -ne 'old font bytes' -or
        (Test-Path -LiteralPath (Join-Path $systemFontDirectory 'NewFontNerdFont-Regular.ttf')) -or
        (Test-Path -LiteralPath (Join-Path $systemFontDirectory 'NewFontNerdFont-Bold.ttf'))) {
        throw 'A failed font installation did not restore the prior font files.'
    }
    if ($script:FakeRegistry[$fontRegistryPath]['Old Font (TrueType)'] -ne 'OldFontNerdFont-Regular.ttf' -or
        $script:FakeRegistry[$stateRegistryPath].TestFont -ne 'previous-state' -or
        $script:FakeRegistry[$fontRegistryPath].ContainsKey('NewFontNerdFont-Regular (TrueType)') -or
        $script:FakeRegistry[$fontRegistryPath].ContainsKey('NewFontNerdFont-Bold (TrueType)')) {
        throw 'A failed font installation did not restore the prior registry state.'
    }
    'PASS: failed font installation restores old files, registrations, and install state.'

    $installedFiles = @(Install-NerdFont -Font $font -NerdFontsVersion '4.0.0' -ExistingFiles $existingFiles -StateRegistryPath $stateRegistryPath)
    if ($installedFiles.Count -ne 2 -or (Test-Path -LiteralPath $oldFontPath) -or
        [System.IO.File]::ReadAllText((Join-Path $systemFontDirectory 'NewFontNerdFont-Regular.ttf')) -ne 'new bytes: NewFontNerdFont-Regular.ttf' -or
        $script:FakeRegistry[$stateRegistryPath].TestFont -notlike '*4.0.0*') {
        throw 'A successful font installation did not commit the replacement set.'
    }
    'PASS: successful font installation commits new files and removes obsolete files.'

    $script:BlockOverwritePath = [System.IO.Path]::GetFullPath($installedFiles[0].FullName)
    $upgradedFiles = @(Install-NerdFont -Font $font -NerdFontsVersion '4.0.0' -ExistingFiles $installedFiles -StateRegistryPath $stateRegistryPath)
    $script:BlockOverwritePath = $null
    if ($upgradedFiles.Count -ne 2) { throw 'An existing font destination must be removed before its replacement is copied.' }
    'PASS: replacement removes existing font files before copying over in-use destinations.'

    $script:FakeRegistry[$stateRegistryPath].Remove('TestFont')
    $script:FailInstallSource = [System.IO.Path]::GetFullPath($script:InstallSources[0])
    $preStateFailure = $null
    try {
        $null = Install-NerdFont -Font $font -NerdFontsVersion '4.0.0' -ExistingFiles $installedFiles -StateRegistryPath $stateRegistryPath
    } catch {
        $preStateFailure = $_
    }
    if (-not $preStateFailure -or
        $preStateFailure.Exception.Message -notlike '*previous font files and registry state were restored*' -or
        $script:FakeRegistry[$stateRegistryPath].ContainsKey('TestFont')) {
        throw "A pre-state failure must roll back without removing an absent registry value: $($preStateFailure.Exception.Message)"
    }
    'PASS: rollback treats an absent prior font-state value as already restored.'

    [System.IO.File]::AppendAllText($script:InstallSources[0], ' changed')
    $script:FailNotificationOnce = $true
    $script:FailRestorePath = [System.IO.Path]::GetFullPath($installedFiles[0].FullName)
    $incompleteRollback = $null
    try {
        $null = Install-NerdFont -Font $font -NerdFontsVersion '4.0.0' -ExistingFiles $installedFiles -StateRegistryPath $stateRegistryPath
    } catch {
        $incompleteRollback = $_
    }
    if (-not $incompleteRollback -or
        $incompleteRollback.Exception.Message -notmatch "Recovery files retained at '(?<recoveryPath>[^']+)'" -or
        -not (Test-Path -LiteralPath $Matches.recoveryPath -PathType Container)) {
        throw "An incomplete rollback must retain its recovery files; got: $($incompleteRollback.Exception.Message)"
    }
    $recoveryFiles = @(Get-ChildItem -LiteralPath $Matches.recoveryPath -File -Recurse)
    if (-not ($recoveryFiles | Where-Object { [System.IO.File]::ReadAllText($_.FullName) -like 'new bytes:*' })) {
        throw 'The retained recovery directory does not contain the previous font files.'
    }
    'PASS: incomplete font rollback retains recovery backups and reports their location.'

    function Invoke-PwshProfileUpdate { $script:ProfileInstallResult }
    function Invoke-CrossPlatformProfileConfiguration { }
    function Invoke-GitHubConfiguration { }
    function Import-PwshProfileConfiguration { }
    $script:ProfileInstallResult = $false
    if (Invoke-PwshProfileConfiguration) { throw 'Profile configuration must return false when installation fails.' }
    $script:ProfileInstallResult = $true
    if (-not (Invoke-PwshProfileConfiguration)) { throw 'Profile configuration must return true after installation succeeds.' }
    $profilePhase = $setupAst.Find({
            param($node)
            $node -is [System.Management.Automation.Language.IfStatementAst] -and
            $node.Extent.Text -match 'Invoke-PwshProfileConfiguration'
        }, $true)
    $updatePhase = $setupAst.Find({
            param($node)
            $node -is [System.Management.Automation.Language.IfStatementAst] -and
            $node.Extent.Text -match '\$profileUpdateSucceeded'
        }, $true)
    if (-not $profilePhase -or $profilePhase.Extent.Text -notmatch '\bthrow\b' -or
        -not $updatePhase -or $updatePhase.Extent.Text -notmatch '\bthrow\b') {
        throw 'Profile and ProfileUpdate phase failures must terminate with an error.'
    }
    'PASS: Profile and ProfileUpdate failures terminate with an error without calling exit.'

    if ((ConvertTo-NerdFontsReleaseVersion -Version 'v4.0.0').ToString() -ne '4.0.0') {
        throw 'Nerd Fonts release version parsing changed unexpectedly.'
    }
    $invalidVersion = $null
    try { ConvertTo-NerdFontsReleaseVersion -Version '4.0-invalid' } catch { $invalidVersion = $_ }
    if (-not $invalidVersion -or $invalidVersion.Exception.Message -notlike '*Invalid Nerd Fonts release version*') {
        throw 'Invalid Nerd Fonts release versions must be rejected.'
    }
    'PASS: Nerd Fonts release versions normalize a v-prefix and reject malformed input.'
} finally {
    $env:TEMP = $originalTemp
    $env:WINDIR = $originalWindows
    Microsoft.PowerShell.Management\Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
