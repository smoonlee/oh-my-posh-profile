$ErrorActionPreference = 'Stop'
$tokens = $null; $errors = $null
$root = Split-Path $PSScriptRoot -Parent
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'src/Invoke-PwshProfileSetup.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
foreach ($name in @('Get-WingetPackageVersionInfo', 'ConvertFrom-WingetTableRow')) {
  $node = $ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true)
  . ([scriptblock]::Create($node.Extent.Text))
}
function Test-Winget {
  if ($args[0] -ne 'list') { throw 'Query attempted a mutation.' }
  $global:LASTEXITCODE = $script:QueryExit
  $script:QueryOutput
}
foreach ($scenario in @('installed', 'absent', 'failed', 'localized', 'empty')) {
  $script:QueryExit = 0
  $script:QueryOutput = @('Name       Id           Version Available Source', '------------------------------------------------', 'Example    Test.App     1.0.0   1.1.0     winget')
  switch ($scenario) {
    'absent' { $script:QueryExit = -1978335212; $script:QueryOutput = 'No packages found' }
    'failed' { $script:QueryExit = 1 }
    'localized' { $script:QueryOutput = 'Unrecognized localized table' }
    'empty' { $script:QueryOutput = @() }
  }
  $failed = $false; $result = $null
  try { $result = Get-WingetPackageVersionInfo -PackageId Test.App -WingetPath Test-Winget } catch { $failed = $true }
  if ($scenario -eq 'installed' -and ($failed -or $result.Id -ne 'Test.App')) { throw 'Installed package rejected.' }
  if ($scenario -eq 'absent' -and ($failed -or $null -ne $result)) { throw 'Absent package not recognized.' }
  if ($scenario -in @('failed', 'localized', 'empty') -and -not $failed) { throw "Unsafe absent result: $scenario" }
}
'PASS: Winget installed, absent, failed, localized, and empty query outcomes.'
& {
  $definition = $ast.Find({
      param($node)
      $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Import-PwshProfileConfiguration'
    }, $true)
  . ([scriptblock]::Create($definition.Extent.Text))
  $reloadRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('profile reload [' + [guid]::NewGuid().ToString('N') + ']')
  $state = @{ Loads = 0; Messages = [System.Collections.Generic.List[object]]::new() }
  function Get-CrossPlatformSupportPaths { @{ SourceRoot = $reloadRoot } }
  function Write-PwshProfileStatus {
    param($Stage, $Type, $Message)
    $state.Messages.Add([pscustomobject]@{ Type = $Type; Message = $Message })
  }
  try {
    New-Item -ItemType Directory -Path $reloadRoot -Force | Out-Null
    $defaultPath = Join-Path $reloadRoot 'Microsoft.PowerShell_profile.ps1'
    $explicitPath = Join-Path $reloadRoot 'custom profile.ps1'
    $PROFILE = Join-Path $reloadRoot 'stale profile.ps1'
    foreach ($path in @($defaultPath, $explicitPath)) {
      Set-Content -LiteralPath $path -Value '$state.Loads++'
    }
    Set-Content -LiteralPath $PROFILE -Value "throw 'The stale PROFILE path must not be loaded.'"
    foreach ($scenario in @('default', 'explicit')) {
      $state.Messages.Clear()
      $previousLoads = $state.Loads
      $expectedPath = if ($scenario -eq 'default') { $defaultPath } else { $explicitPath }
      if ($scenario -eq 'default') {
        Import-PwshProfileConfiguration
      } else {
        Import-PwshProfileConfiguration -Path $explicitPath
      }
      if ($state.Loads -ne ($previousLoads + 1) -or $state.Messages[-1].Type -ne 'Success' -or
        $state.Messages[0].Message -ne "Reloading into the current session: $expectedPath") {
        throw "The $scenario reload must load and report the validated profile path."
      }
      "PASS: $scenario profile reload ignores a stale PROFILE path."
    }
    $state.Messages.Clear()
    $previousLoads = $state.Loads
    Import-PwshProfileConfiguration -Path (Join-Path $reloadRoot 'missing profile.ps1')
    if ($state.Loads -ne $previousLoads -or $state.Messages.Count -ne 1 -or
      $state.Messages[0].Type -ne 'Warning' -or $state.Messages[0].Message -notlike '*was not found*') {
      throw 'A missing profile must warn without loading another profile.'
    }
    'PASS: missing profile reload warns without falling back to PROFILE.'
    Set-Content -LiteralPath $explicitPath -Value "throw 'Synthetic profile load failure'"
    $state.Messages.Clear()
    Import-PwshProfileConfiguration -Path $explicitPath
    if ($state.Messages[-1].Type -ne 'Warning' -or
      $state.Messages[-1].Message -notlike '*Synthetic profile load failure*') {
      throw 'Profile load errors must retain the original failure details.'
    }
    'PASS: profile load errors are reported without escaping the reload helper.'
  } finally {
    Remove-Item -LiteralPath $reloadRoot -Recurse -Force -ErrorAction Ignore
  }
}
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'src/profile/Microsoft.PowerShell_profile.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$guard = $ast.Find({ param($n) $n -is [Management.Automation.Language.TryStatementAst] -and $n.Body.Extent.Text -match '^\{\s*Start-PwshProfileUpdateCheck' }, $true)
function Start-PwshProfileUpdateCheck { throw 'Synthetic cache write failure' }
$profileSettings = @{ EnablePreReleaseUpdate = $false }
& ([scriptblock]::Create($guard.Extent.Text))
'PASS: update-cache failure does not escape optional startup check.'
$updateCheck = $ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Start-PwshProfileUpdateCheck' }, $true)
. ([scriptblock]::Create($updateCheck.Extent.Text))
function global:Compare-PwshProfileSemanticVersion { return 0 }
function global:Get-PwshProfileReleasePages { return @() }
function Start-Process { throw 'Synthetic process launch failure' }
$updateCheckRoot = Join-Path ([System.IO.Path]::GetTempPath()) "PwshProfileLaunchFailure-$([guid]::NewGuid().ToString('n'))"
try {
  New-Item -ItemType Directory -Path $updateCheckRoot -ErrorAction Stop | Out-Null
  Start-PwshProfileUpdateCheck -StorePath $updateCheckRoot -Repository 'owner/repository' -CurrentVersion '1.0.0'
  if (Test-Path -LiteralPath (Join-Path $updateCheckRoot 'update-state.json')) {
    throw 'A failed background-process launch left a throttling state file.'
  }
} finally {
  Remove-Item -LiteralPath $updateCheckRoot -Recurse -Force -ErrorAction Ignore
  Remove-Item Function:Start-Process -ErrorAction Ignore
  Remove-Item Function:Start-PwshProfileUpdateCheck -ErrorAction Ignore
  Remove-Item Function:global:Compare-PwshProfileSemanticVersion -ErrorAction Ignore
  Remove-Item Function:global:Get-PwshProfileReleasePages -ErrorAction Ignore
}
'PASS: failed update-check launch does not suppress retries.'
if (Get-Command oh-my-posh -ErrorAction Ignore) {
  $theme = Join-Path $root 'src/themes/quick-term-cloud.omp.json'
  foreach ($iteration in 1..2) {
    $initialization = oh-my-posh init pwsh --config $theme
    if ($LASTEXITCODE -ne 0 -or -not $initialization) { throw 'OMP initialization generation failed.' }
    $initialization | Invoke-Expression
    $activeModule = (Get-Command prompt -CommandType Function).Module
    if (-not $activeModule -or $activeModule.Name -ne 'oh-my-posh-core') { throw 'Active OMP prompt module could not be resolved.' }
  }
  'PASS: active OMP module resolved after initial and repeated initialization.'
}
