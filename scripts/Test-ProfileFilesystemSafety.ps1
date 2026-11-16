$ErrorActionPreference = 'Stop'
$setupPath = Join-Path $PSScriptRoot '../src/Invoke-PwshProfileSetup.ps1'
$tokens = $null
$parseErrors = $null
$setupAst = [System.Management.Automation.Language.Parser]::ParseFile($setupPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
$definition = $setupAst.Find({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Set-PwshSymbolicLink'
    }, $true)
if (-not $definition) { throw 'Set-PwshSymbolicLink was not found.' }
. ([scriptblock]::Create($definition.Extent.Text))

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('profile-link-safety-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $testRoot -Force
$script:FailSymlinkCreation = $true
function Write-PwshProfileStatus { param($Stage, $Type, $Message) }
function New-Item {
    [CmdletBinding()]
    param([string] $ItemType, [string] $Path, [string] $Target, [switch] $Force)
    if ($ItemType -eq 'SymbolicLink') {
        if ($script:FailSymlinkCreation) { throw 'Synthetic link failure' }
        [IO.File]::WriteAllText($Path, 'synthetic link')
        return Get-Item -LiteralPath $Path
    }
    Microsoft.PowerShell.Management\New-Item -ItemType $ItemType -Path $Path -Force:$Force
}

try {
    $profilePath = Join-Path $testRoot 'Microsoft.PowerShell_profile.ps1'
    $targetPath = Join-Path $testRoot 'target-profile.ps1'
    [IO.File]::WriteAllText($profilePath, 'user profile content')
    [IO.File]::WriteAllText($targetPath, 'managed profile content')

    $failedLink = Set-PwshSymbolicLink -Path $profilePath -Target $targetPath -ItemType File
    if ($failedLink -or -not (Test-Path -LiteralPath $profilePath -PathType Leaf) -or
        [IO.File]::ReadAllText($profilePath) -ne 'user profile content' -or
        @(Get-ChildItem -LiteralPath $testRoot -Filter '*.bak').Count) {
        throw 'A failed symlink creation must restore the original profile file in place.'
    }
    'PASS: failed symlink creation restores an existing profile file.'

    $script:FailSymlinkCreation = $false
    $linked = Set-PwshSymbolicLink -Path $profilePath -Target $targetPath -ItemType File
    $backups = @(Get-ChildItem -LiteralPath $testRoot -Filter 'Microsoft.PowerShell_profile.ps1.*.bak' -File)
    if (-not $linked -or $backups.Count -ne 1 -or
        [IO.File]::ReadAllText($backups[0].FullName) -ne 'user profile content' -or
        [IO.File]::ReadAllText($profilePath) -ne 'synthetic link') {
        throw 'A successful symlink creation must retain the original profile as a backup.'
    }
    'PASS: successful symlink creation retains the original profile backup.'
} finally {
    Remove-Item Function:\New-Item -ErrorAction Ignore
    Remove-Item Function:\Write-PwshProfileStatus -ErrorAction Ignore
    Microsoft.PowerShell.Management\Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}