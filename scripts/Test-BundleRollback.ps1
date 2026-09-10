$ErrorActionPreference = 'Stop'
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
  (Join-Path $PSScriptRoot '../src/Invoke-PwshProfileSetup.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$handlers = @($ast.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CatchClauseAst] -and
  $node.Extent.Text -like '*$recovery = if ($rollbackErrors.Count)*'
}, $true))
if ($handlers.Count -ne 2) { throw 'Expected both bundle rollback handlers.' }
function Test-Path { $true }
function Copy-Item { if ($script:FailRestore) { throw 'Synthetic access denied' } }
function Write-PwshProfileStatus { param($Stage, $Type, $Message) $script:ResultMessage = $Message }
$replaced = @('profile')
$backups = @{ profile = 'synthetic.profile.bak' }
$destinations = @{ profile = 'synthetic.profile.ps1' }
$destinationExisted = @{ profile = $true }
$operation = 'Update'
foreach ($handler in $handlers) {
  foreach ($failure in @($false, $true)) {
    $script:FailRestore = $failure
    $code = [scriptblock]::Create("try { throw 'Synthetic installation failure' } " + $handler.Extent.Text)
    $null = & $code
    if ($script:ResultMessage -notlike '*Synthetic installation failure*') { throw 'Original error lost.' }
    if ($failure) {
      if ($script:ResultMessage -notlike '*Rollback incomplete*synthetic.profile.ps1*Synthetic access denied*synthetic.profile.bak*') {
        throw "Missing recovery details: $script:ResultMessage"
      }
    } elseif ($script:ResultMessage -notlike '*Previous files were restored*') { throw 'Successful restoration not reported.' }
  }
}
'PASS: local and published bundle rollback distinguish successful and failed restoration.'
