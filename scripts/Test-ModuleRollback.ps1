$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repo 'src/Invoke-PwshProfileSetup.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$atomic = $ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Install-PwshProfileAtomicFile' }, $true)
. ([scriptblock]::Create($atomic.Extent.Text))
$script:AtomicImpl = ${function:Install-PwshProfileAtomicFile}
function Install-PwshProfileAtomicFile {
  param($StagedPath, $Destination, $BackupPath)
  $script:Calls++
  if ($script:FailAfter -eq $script:Calls) { throw 'Injected write failure' }
  & $script:AtomicImpl -StagedPath $StagedPath -Destination $Destination -BackupPath $BackupPath
}
function Write-PwshProfileStatus { }
$updater = $ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Invoke-PwshProfileModuleUpdateCore' }, $true).Extent.Text
$start = $updater.IndexOf('  $wasLoaded =')
$end = $updater.IndexOf("  Write-PwshProfileStatus -Stage 'Complete'", $start)
$transaction = [scriptblock]::Create($updater.Substring($start, $end - $start))
foreach ($scenario in @('write', 'import')) {
  $moduleRoot = Join-Path ([IO.Path]::GetTempPath()) ('rollback-' + [guid]::NewGuid().ToString('N'))
  $null = New-Item -ItemType Directory -Path $moduleRoot
  $ModuleName = 'PwshProfile.RollbackTest'
  $installedManifestPath = Join-Path $moduleRoot "$ModuleName.psd1"
  $modulePath = Join-Path $moduleRoot "$ModuleName.psm1"
  $manifest = "@{ RootModule = '$ModuleName.psm1'; ModuleVersion = '1.0.0'; FunctionsToExport = @('Get-RollbackTestValue') }"
  [IO.File]::WriteAllText($installedManifestPath, $manifest)
  [IO.File]::WriteAllText($modulePath, "function Get-RollbackTestValue { 'old' }; Export-ModuleMember -Function Get-RollbackTestValue")
  try {
    Import-Module $installedManifestPath -Global -Force
    $artifactNames = [ordered]@{ added = 'new.ps1xml'; script = "$ModuleName.psm1"; manifest = "$ModuleName.psd1" }
    $staged = @{}
    foreach ($name in $artifactNames.Keys) {
      $staged[$name] = Join-Path $moduleRoot "$name.stage"
      $content = switch ($name) {
        'added' { '<Configuration />' }
        'script' { if ($scenario -eq 'import') { "throw 'Injected import failure'" } else { "function Get-RollbackTestValue { 'new' }" } }
        'manifest' { $manifest }
      }
      [IO.File]::WriteAllText($staged[$name], $content)
    }
    $script:Calls = 0
    $script:FailAfter = if ($scenario -eq 'write') { 3 } else { 0 }
    $failed = $false
    try { & $transaction } catch {
      $failed = $true
      if ($_.Exception.Message -notlike '*previous files and loaded state were restored*') { throw }
    }
    if (-not $failed) { throw 'Injected failure was not reached' }
    if (Test-Path (Join-Path $moduleRoot 'new.ps1xml')) { throw 'New artifact survived rollback' }
    if ((Get-RollbackTestValue) -ne 'old') { throw 'Old module was not reloaded' }
    if ((Get-Content $modulePath -Raw) -notlike "*'old'*") { throw 'Old script was not restored' }
    "PASS: $scenario failure removes new files, restores old files, and reloads previous module."
  }
  finally {
    Remove-Module $ModuleName -Force -ErrorAction Ignore
    Get-ChildItem -LiteralPath $moduleRoot -File -Force | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
    Remove-Item -LiteralPath $moduleRoot
  }
}
