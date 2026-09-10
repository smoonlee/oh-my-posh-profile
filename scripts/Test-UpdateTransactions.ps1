$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'src/Invoke-PwshProfileSetup.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors.Message -join '; ') }
foreach ($name in @('Invoke-PwshProfileUpdateTransaction', 'Install-PwshProfileAtomicFile', 'Get-PwshProfileReleasePages')) {
  $definition = $ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true)
  Invoke-Expression $definition.Extent.Text
}
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('profile-transaction-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory $testRoot
function Get-PwshProfileLocalStorePaths { @{ Root = $testRoot } }
function Invoke-RestMethod {
  param($Uri, $Headers, $TimeoutSec, $ErrorAction)
  $script:Requests++
  if ($Uri -match 'page=1$') { ,@(1..100) } elseif ($Uri -match 'page=2$') { ,@(101) } else { throw 'Unexpected page' }
}
$script:Requests = 0
$items = @(Get-PwshProfileReleasePages -Uri 'https://test/releases?per_page=100' -Headers @{})
if ($items.Count -ne 101 -or $script:Requests -ne 2) { throw 'Release pagination failed.' }
'PASS: release discovery reads beyond the first 100 releases.'

# Exercise both copies without loading the profile or running setup.
foreach ($source in @('src/Invoke-PwshProfileSetup.ps1', 'src/profile/Microsoft.PowerShell_profile.ps1')) {
  $sourceAst = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root $source), [ref]$tokens, [ref]$errors)
  if ($errors.Count) { throw ($errors.Message -join '; ') }
  $definition = $sourceAst.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -match '^(global:)?Get-PwshProfileReleasePages$' }, $true)
  Invoke-Expression ($definition.Extent.Text -replace 'function global:', 'function ')
  function Invoke-RestMethod {
    param($Uri, $Headers, $TimeoutSec, $ErrorAction)
    $script:Requests++
    if ($Uri -match 'page=1$') { ,@(1..100) } elseif ($Uri -match 'page=2$') { ,@(101) } else { throw 'Unexpected page' }
  }
  $script:Requests = 0
  $items = @(Get-PwshProfileReleasePages -Uri 'https://test/releases?per_page=100' -Headers @{})
  if ($items.Count -ne 101 -or $script:Requests -ne 2) { throw "Pagination failed: $source" }
  function Invoke-RestMethod {
    param($Uri, $Headers, $TimeoutSec, $ErrorAction)
    ,$script:ReleaseFixture
  }
  foreach ($count in @(0, 1, 2)) {
    $script:ReleaseFixture = @(for ($i = 0; $i -lt $count; $i++) {
      [pscustomobject]@{ tag_name = "v4.0.0-pre-release-0.9.8.$i"; draft = $false; prerelease = $true }
    })
    $items = @(Get-PwshProfileReleasePages -Uri 'https://test/releases?per_page=100' -Headers @{})
    if ($items.Count -ne $count -or @($items | Where-Object { -not $_.draft -and $_.prerelease }).Count -ne $count) {
      throw "Release array handling failed for $count entries: $source"
    }
  }
  "PASS: $source handles empty, single, multiple, and paginated REST arrays."
}
foreach ($name in @('Get-PwshProfileGitHubRelease', 'Compare-PwshProfileSemanticVersion')) {
  $definition = $ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true)
  Invoke-Expression $definition.Extent.Text
}
$script:ReleaseFixture = @(
  [pscustomobject]@{ tag_name = 'v4.0.0-pre-release-0.9.7'; draft = $false; prerelease = $true }
  [pscustomobject]@{ tag_name = 'PwshProfile.Dns-v1.0.1'; draft = $false; prerelease = $false }
  [pscustomobject]@{ tag_name = 'v4.0.0-pre-release-0.9.8.1'; draft = $false; prerelease = $true }
  [pscustomobject]@{ tag_name = 'v4.0.0-pre-release-0.9.9'; draft = $true; prerelease = $true }
  [pscustomobject]@{ tag_name = 'v4.0.0'; draft = $false; prerelease = $false }
)
if ((Get-PwshProfileGitHubRelease -Prerelease).tag_name -ne 'v4.0.0-pre-release-0.9.8.1') { throw 'Latest prerelease not selected.' }
if ((Get-PwshProfileGitHubRelease).tag_name -ne 'v4.0.0') { throw 'Stable release not selected.' }
'PASS: release selection picks the latest published version in the requested channel.'

$lockPath = Join-Path $testRoot 'update.lock'
$journalPath = Join-Path $testRoot 'update-journal.json'
$lock = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None')
try {
  $refused = $false
  try { Invoke-PwshProfileUpdateTransaction { throw 'Action must not run' } } catch {
    if ($_.Exception.Message -notlike '*Another profile update*') { throw }
    $refused = $true
  }
  if (-not $refused) { throw 'Concurrent update was accepted.' }
} finally { $lock.Dispose() }
'PASS: concurrent updater refused before mutation.'
$destination = Join-Path $testRoot 'installed.txt'
$staged = Join-Path $testRoot 'staged.txt'
$backup = Join-Path $testRoot 'backup.txt'
[IO.File]::WriteAllText($destination, 'original')
[IO.File]::WriteAllText($staged, 'replacement')
try {
  Invoke-PwshProfileUpdateTransaction {
    Install-PwshProfileAtomicFile -StagedPath $staged -Destination $destination -BackupPath $backup
    throw 'Simulated interruption after replacement'
  }
} catch { if ($_.Exception.Message -notlike '*Simulated interruption*') { throw } }
$journal = @(Get-Content $journalPath -Raw | ConvertFrom-Json)
if ($journal.Count -ne 1 -or [IO.File]::ReadAllText($journal[0].backup) -ne 'original') { throw 'Recovery evidence missing.' }
$refused = $false
try { Invoke-PwshProfileUpdateTransaction { throw 'Action must not run' } } catch {
  if ($_.Exception.Message -notlike '*interrupted update requires recovery*') { throw }
  $refused = $true
}
if (-not $refused -or [IO.File]::ReadAllText($destination) -ne 'replacement') { throw 'Recovery gate modified installed files.' }
'PASS: interrupted transaction retains original content and blocks further updates.'
# Explicit recovery of our synthetic fixture, as documented for users.
[IO.File]::Copy($journal[0].backup, $destination, $true)
Remove-Item -LiteralPath $journalPath
[IO.File]::WriteAllText($staged, 'completed')
$result = Invoke-PwshProfileUpdateTransaction {
  Install-PwshProfileAtomicFile -StagedPath $staged -Destination $destination -BackupPath ($backup + '.retry')
  $true
}
if ($result -ne $true -or (Test-Path $journalPath) -or [IO.File]::ReadAllText($destination) -ne 'completed') { throw 'Recovered retry failed.' }
'PASS: successful retry clears the journal.'
