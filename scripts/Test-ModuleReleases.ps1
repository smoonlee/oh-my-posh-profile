$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$moduleNames = @((Get-ChildItem (Join-Path $root 'src/modules') -Directory -Filter 'PwshProfile.*').Name) + 'PwshProfile.FutureModule'
$commit = 'a' * 40
$global:PwshModuleReleaseTestState = @{}
function gh {
  $global:LASTEXITCODE = 0
  if ($args[0] -ne 'api') { throw 'Unexpected command' }
  if ($args[1] -eq '--method') {
    if ($global:PwshModuleReleaseTestState.Scenario -eq 'create-failure') { $global:LASTEXITCODE = 1; return }
    if ($args -notcontains "ref=refs/tags/$($global:PwshModuleReleaseTestState.Tag)" -or $args -notcontains "sha=$commit") { throw 'Incorrect tag creation request' }
    $global:PwshModuleReleaseTestState.Created++
    $global:PwshModuleReleaseTestState.Exists = $true
    return '{}'
  }
  if ($args[1] -like '*/git/matching-refs/*') {
    if ($global:PwshModuleReleaseTestState.Scenario -eq 'query-failure') { $global:LASTEXITCODE = 1; return }
    # A prefix match for 1.0.10 must not count as an existing 1.0.1 tag.
    $refs = @([pscustomobject]@{ ref = "refs/tags/$($global:PwshModuleReleaseTestState.Tag)0" })
    if ($global:PwshModuleReleaseTestState.Exists) { $refs += [pscustomobject]@{ ref = "refs/tags/$($global:PwshModuleReleaseTestState.Tag)" } }
    ConvertTo-Json -InputObject $refs
    return
  }
  if ($args[1] -like '*/commits/*') {
    if (-not $global:PwshModuleReleaseTestState.Exists) { throw 'Tag was checked before creation' }
    if ($global:PwshModuleReleaseTestState.Scenario -eq 'resolve-failure') { $global:LASTEXITCODE = 1; return }
    if ($global:PwshModuleReleaseTestState.Scenario -eq 'wrong-commit') { 'b' * 40 } else { $commit }
    return
  }
  throw 'Unexpected API request'
}
foreach ($moduleName in $moduleNames) {
  $global:PwshModuleReleaseTestState.Tag = "$moduleName-v1.0.1"
  foreach ($scenario in @('new','retry-draft','wrong-commit','query-failure','create-failure','resolve-failure')) {
    $global:PwshModuleReleaseTestState.Scenario = $scenario
    $global:PwshModuleReleaseTestState.Exists = $scenario -in @('retry-draft','wrong-commit')
    $global:PwshModuleReleaseTestState.Created = 0
    $failure = $null
    try { & "$PSScriptRoot/Ensure-PwshProfileModuleTag.ps1" -Repository test/repository -Tag $global:PwshModuleReleaseTestState.Tag -Commit $commit } catch { $failure = $_ }
    if ($scenario -in @('new','retry-draft')) {
      if ($failure) { throw $failure }
      $expectedCreates = if ($scenario -eq 'new') { 1 } else { 0 }
      if ($global:PwshModuleReleaseTestState.Created -ne $expectedCreates) { throw 'Unexpected tag creation count' }
    } elseif (-not $failure) { throw "Unsafe tag accepted: $scenario" }
    if ($scenario -in @('wrong-commit','query-failure') -and $global:PwshModuleReleaseTestState.Created) { throw 'Existing or unknown tag was replaced' }
  }
  "PASS: $moduleName tag creation, draft retry, and failure guards."
}
# Exercise the real discovery and version selector with all repository modules
# and a name that is deliberately absent from any built-in module list.
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'src/Invoke-PwshProfileSetup.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors.Message -join '; ') }
foreach ($name in @('Compare-PwshProfileSemanticVersion','Get-PwshProfileModuleGitHubRelease','Invoke-PwshProfileIndependentModuleUpdates')) {
  $definition = $ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true)
  Invoke-Expression $definition.Extent.Text
}
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('module-discovery-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $testRoot
$global:PwshModuleReleaseTestState.ReleaseFixture = @(
  foreach ($name in ($moduleNames + 'PwshProfile.NotInstalled')) {
    foreach ($version in @('1.0.1','1.0.2')) {
      [pscustomobject]@{ tag_name = "$name-v$version"; draft = $false; prerelease = $false }
    }
    [pscustomobject]@{ tag_name = "$name-v9.0.0"; draft = $true; prerelease = $false }
  }
  [pscustomobject]@{ tag_name = 'v4.0.0'; draft = $false; prerelease = $false }
)
function Get-PwshProfileReleasePages { $global:PwshModuleReleaseTestState.ReleaseFixture }
function Get-PwshProfileLocalStorePaths { @{ Modules = $testRoot } }
function Write-PwshProfileStatus { param($Stage, $Type, $Message) }
function Invoke-PwshProfileModuleUpdate {
  param($ModuleName, $Repository, [switch]$Prerelease, $Releases)
  $selected = Get-PwshProfileModuleGitHubRelease @PSBoundParameters
  if ($selected.tag_name -ne "$ModuleName-v1.0.2") { throw 'Wrong module release selected' }
  $global:PwshModuleReleaseTestState.Visited.Add($ModuleName)
  if ($ModuleName -eq $global:PwshModuleReleaseTestState.FailModule) { throw 'Injected module failure' }
  $true
}
foreach ($name in $moduleNames) {
  $directory = Join-Path $testRoot $name
  $null = New-Item -ItemType Directory -Path $directory
  Set-Content (Join-Path $directory "$name.psd1") "@{ ModuleVersion = '1.0.0' }"
}
foreach ($failModule in @('', $moduleNames[0])) {
  $global:PwshModuleReleaseTestState.FailModule = $failModule
  $global:PwshModuleReleaseTestState.Visited = [Collections.Generic.List[string]]::new()
  $result = Invoke-PwshProfileIndependentModuleUpdates -Repository test/repository -Prerelease
  if ($result -ne (-not [bool]$failModule)) { throw 'Module failures were not reported' }
  if ((@($global:PwshModuleReleaseTestState.Visited | Sort-Object) -join ',') -ne (@($moduleNames | Sort-Object) -join ',')) { throw 'Discovery skipped a module or tried an uninstalled module' }
}
'PASS: all current and future installed modules are discovered; drafts are ignored and one failure does not stop other updates.'

Remove-Variable PwshModuleReleaseTestState -Scope Global
