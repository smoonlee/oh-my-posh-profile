$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('eol-release-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $testRoot 'src/modules/PwshProfile.EndOfLife') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $testRoot 'src/profile') -Force | Out-Null
$manifest = Join-Path $testRoot 'src/modules/PwshProfile.EndOfLife/PwshProfile.EndOfLife.psd1'
$profile = Join-Path $testRoot 'src/profile/Microsoft.PowerShell_profile.ps1'
$log = Join-Path $testRoot 'src/modules/PwshProfile.EndOfLife/CHANGELOG.md'
$previous = Join-Path $testRoot 'previous.json'
$current = Join-Path $testRoot 'EndOfLifeProducts.json'
foreach ($profileVersion in @('4.0.0', '4.0.0-pre-release-0.9.6')) {
  Set-Content $manifest "@{`n  ModuleVersion = '1.0.1'`n}"
  Set-Content $profile "`$script:PwshProfileVersion = '$profileVersion'"
  Set-Content $log "# Module changelog`n`n## [1.0.1]`n`nExisting notes."
  Set-Content $previous '{"Products":["alpha","removed"]}'
  Set-Content $current '{"Products":["alpha","added"]}'
  & "$PSScriptRoot/Update-EndOfLifeRelease.ps1" -PreviousCatalogPath $previous -RepositoryRoot $testRoot
  if ((Import-PowerShellDataFile $manifest).ModuleVersion -ne '1.1.0') { throw 'Module minor bump failed.' }
  if ((Get-Content $profile -Raw) -notmatch [regex]::Escape($profileVersion)) { throw 'Profile version changed.' }
  $notes = Get-Content $log -Raw
  foreach ($expected in @('## [1.1.0]', 'Added products: `added`', 'Removed products: `removed`', 'Existing notes.')) {
    if (-not $notes.Contains($expected)) { throw "Missing changelog text: $expected" }
  }
  Copy-Item $current $previous -Force
  $before = @($manifest, $profile, $log | ForEach-Object { (Get-FileHash $_).Hash }) -join ','
  & "$PSScriptRoot/Update-EndOfLifeRelease.ps1" -PreviousCatalogPath $previous -RepositoryRoot $testRoot
  $after = @($manifest, $profile, $log | ForEach-Object { (Get-FileHash $_).Hash }) -join ','
  if ($before -ne $after) { throw 'Unchanged catalog modified release files.' }
}
foreach ($path in @('scripts/Update-EndOfLifeRelease.ps1', 'scripts/Update-EndOfLifeProducts.ps1', 'src/modules/PwshProfile.EndOfLife/PwshProfile.EndOfLife.psm1', 'src/profile/Microsoft.PowerShell_profile.ps1')) {
  $tokens = $null
  $errors = $null
  [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $root $path), [ref]$tokens, [ref]$errors)
  if ($errors.Count) { throw ($errors.Message -join '; ') }
}
$setupPath = Join-Path $root 'src/Invoke-PwshProfileSetup.ps1'
$setupTokens = $null
$setupErrors = $null
$setupAst = [Management.Automation.Language.Parser]::ParseFile($setupPath, [ref]$setupTokens, [ref]$setupErrors)
if ($setupErrors.Count) { throw ($setupErrors.Message -join '; ') }
foreach ($functionName in @(
  'Compare-PwshProfileSemanticVersion',
  'Get-PwshProfileReleasePages',
  'Get-PwshProfileGitHubRelease',
  'Get-PwshProfileModuleGitHubRelease',
  'Invoke-PwshProfileModuleUpdate'
  'Invoke-PwshProfileModuleUpdateCore'
  'Invoke-PwshProfileUpdateTransaction'
  'Protect-PwshProfileNewerModules'
  'Install-PwshProfileAtomicFile'
)) {
  $definition = $setupAst.Find({
      param($node)
      $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $functionName
    }, $true)
  if (-not $definition) { throw "Missing updater function: $functionName" }
  Invoke-Expression $definition.Extent.Text
}
function Invoke-RestMethod {
  @(
    [pscustomobject]@{ tag_name = 'PwshProfile.EndOfLife-v1.1.0'; draft = $false; prerelease = $false }
    [pscustomobject]@{ tag_name = 'PwshProfile.Dns-v2.0.0'; draft = $false; prerelease = $false }
    [pscustomobject]@{ tag_name = 'v4.0.0'; draft = $false; prerelease = $false }
    [pscustomobject]@{ tag_name = 'v4.1.0-pre.1'; draft = $false; prerelease = $true }
  )
}
if ((Get-PwshProfileGitHubRelease).tag_name -ne 'v4.0.0') {
  throw 'Stable profile selection accepted a module release tag.'
}
if ((Get-PwshProfileGitHubRelease -Prerelease).tag_name -ne 'v4.1.0-pre.1') {
  throw 'Prerelease profile selection failed.'
}
if ((Get-PwshProfileModuleGitHubRelease -ModuleName 'PwshProfile.EndOfLife').tag_name -ne 'PwshProfile.EndOfLife-v1.1.0') {
  throw 'Independent module release selection failed.'
}
if ((Get-PwshProfileModuleGitHubRelease -ModuleName 'PwshProfile.Dns').tag_name -ne 'PwshProfile.Dns-v2.0.0') {
  throw 'Generic module release selection failed.'
}
$moduleName = 'PwshProfile.EndOfLife'
$moduleStore = Join-Path $testRoot 'installed/modules/PwshProfile.EndOfLife'
$releaseStore = Join-Path $testRoot 'module-release'
New-Item -ItemType Directory -Path $moduleStore, $releaseStore -Force | Out-Null
Set-Content (Join-Path $moduleStore "$moduleName.psd1") "@{ RootModule='$moduleName.psm1'; ModuleVersion='1.0.1' }"
Set-Content (Join-Path $moduleStore "$moduleName.psm1") 'function Get-OldValue { 1 }'
Set-Content (Join-Path $moduleStore "$moduleName.Format.ps1xml") '<Configuration />'
Set-Content (Join-Path $releaseStore "$moduleName.psd1") "@{ RootModule='$moduleName.psm1'; ModuleVersion='1.1.0' }"
Set-Content (Join-Path $releaseStore "$moduleName.psm1") 'function Get-NewValue { 2 }'
Set-Content (Join-Path $releaseStore "$moduleName.Format.ps1xml") '<Configuration />'
$artifactFiles = [ordered]@{
  manifest = "$moduleName.psd1"
  script = "$moduleName.psm1"
  format = "$moduleName.Format.ps1xml"
}
$moduleReleaseManifest = [ordered]@{
  schemaVersion = 1
  module = $moduleName
  version = '1.1.0'
  tag = "$moduleName-v1.1.0"
  repository = 'test/repository'
  artifacts = [ordered]@{}
}
foreach ($entry in $artifactFiles.GetEnumerator()) {
  $moduleReleaseManifest.artifacts[$entry.Key] = [ordered]@{
    asset = $entry.Value
    sha256 = (Get-FileHash (Join-Path $releaseStore $entry.Value)).Hash.ToLowerInvariant()
  }
}
$moduleReleaseManifest | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $releaseStore "$moduleName.release.json")
function Get-PwshProfileModuleGitHubRelease {
  [pscustomobject]@{
    tag_name = 'PwshProfile.EndOfLife-v1.1.0'
    assets = @($artifactFiles.Values + "$moduleName.release.json" | ForEach-Object {
      [pscustomobject]@{ name = $_; browser_download_url = "https://test/$_" }
    })
  }
}
function Get-PwshProfileLocalStorePaths {
  [pscustomobject]@{ Root = (Join-Path $testRoot 'installed'); Modules = (Split-Path $moduleStore -Parent) }
}
function Save-PwshProfileReleaseAsset { param($Uri, $Destination) Copy-Item (Join-Path $releaseStore ([IO.Path]::GetFileName($Uri))) $Destination }
function Write-PwshProfileStatus { param($Stage, $Message, $Type) }
function Write-PwshProfileHeader { param($Title, $Subtitle) }
function Test-PwshProfileScriptFile {
  param($Path, $Label)
  $tokens = $null; $errors = $null
  [void][Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
  if ($errors.Count) { throw ($errors.Message -join '; ') }
}
$atomicImplementation = ${function:Install-PwshProfileAtomicFile}
function Install-PwshProfileAtomicFile {
  param($StagedPath, $Destination, $BackupPath)
  if ($script:FailMetadata -and $Destination -eq $baselinePath) { throw 'Injected metadata failure' }
  & $atomicImplementation -StagedPath $StagedPath -Destination $Destination -BackupPath $BackupPath
}
$baselinePath = Join-Path $testRoot 'installed/version.json'
$baseline = @{ schemaVersion = 2; version = '4.0.0'; artifacts = @{} }
foreach ($entry in $artifactFiles.GetEnumerator()) {
  $baseline.artifacts[$entry.Key] = @{ file = $entry.Value; sha256 = (Get-FileHash (Join-Path $moduleStore $entry.Value)).Hash }
}
$baseline | ConvertTo-Json -Depth 8 | Set-Content $baselinePath
$originalScript = Get-Content (Join-Path $moduleStore "$moduleName.psm1") -Raw
Add-Content (Join-Path $moduleStore "$moduleName.psm1") '# local edit'
$refused = $false
try { Invoke-PwshProfileModuleUpdate -ModuleName $moduleName -Repository 'test/repository' } catch {
  if ($_.Exception.Message -notlike '*differs from its baseline*') { throw }
  $refused = $true
}
if (-not $refused) { throw 'Independent update overwrote local edits.' }
[IO.File]::WriteAllText((Join-Path $moduleStore "$moduleName.psm1"), $originalScript)
$baselineHash = (Get-FileHash $baselinePath).Hash
$script:FailMetadata = $true
$refused = $false
try { Invoke-PwshProfileModuleUpdate -ModuleName $moduleName -Repository 'test/repository' } catch {
  if ($_.Exception.Message -notlike '*Injected metadata failure*') { throw }
  $refused = $true
}
if (-not $refused) { throw 'Metadata failure was not exercised.' }
if ((Get-FileHash $baselinePath).Hash -ne $baselineHash) { throw 'Failed commit changed metadata.' }
foreach ($entry in $baseline.artifacts.Values) {
  if ((Get-FileHash (Join-Path $moduleStore $entry.file)).Hash -ine $entry.sha256) { throw 'Failed metadata commit did not restore module files.' }
}
$script:FailMetadata = $false
Write-Host 'PASS: metadata commit failure restores original module and baseline.'
[void](Invoke-PwshProfileModuleUpdate -ModuleName $moduleName -Repository 'test/repository')
$updatedBaseline = Get-Content $baselinePath -Raw | ConvertFrom-Json
foreach ($entry in $updatedBaseline.artifacts.PSObject.Properties) {
  if ((Get-FileHash (Join-Path $moduleStore $entry.Value.file)).Hash -ine $entry.Value.sha256) {
    throw 'Independent update left bundle baseline stale.'
  }
}
Write-Host 'PASS: independent updates reject drift and refresh bundle baseline hashes.'
$bundleStage = @{}
$bundleDestinations = @{}
foreach ($entry in $artifactFiles.GetEnumerator()) {
  $bundleStage[$entry.Key] = Join-Path $testRoot ($entry.Value + '.bundle')
  $bundleDestinations[$entry.Key] = Join-Path $moduleStore $entry.Value
  Copy-Item $bundleDestinations[$entry.Key] $bundleStage[$entry.Key]
}
foreach ($bundleVersion in @('1.0.1', '1.2.0')) {
  Set-Content $bundleStage.manifest "@{ RootModule='$moduleName.psm1'; ModuleVersion='$bundleVersion' }"
  Set-Content $bundleStage.script 'function Get-BundleValue { 3 }'
  $bundleMetadata = $moduleReleaseManifest | ConvertTo-Json -Depth 8 | ConvertFrom-Json
  Protect-PwshProfileNewerModules -ArtifactNames $artifactFiles -Destinations $bundleDestinations -StagedPaths $bundleStage -InstalledBaseline $updatedBaseline -ReleaseManifest $bundleMetadata
  $expectedVersion = if ($bundleVersion -eq '1.0.1') { '1.1.0' } else { '1.2.0' }
  if ((Import-PowerShellDataFile $bundleStage.manifest).ModuleVersion -ne $expectedVersion) { throw 'Bundle would downgrade or incorrectly pin a module.' }
  if ($bundleVersion -eq '1.0.1') {
    foreach ($entry in $artifactFiles.GetEnumerator()) {
      if ((Get-FileHash $bundleStage[$entry.Key]).Hash -ine $bundleMetadata.artifacts.($entry.Key).sha256) { throw 'Preserved bundle hashes disagree with staged files.' }
    }
  }
}
Write-Host 'PASS: older bundle preserves independent module and hashes; newer bundle permits upgrade.'
if ((Import-PowerShellDataFile (Join-Path $moduleStore "$moduleName.psd1")).ModuleVersion -ne '1.1.0') {
  throw 'Independent module installation failed.'
}
Import-Module (Join-Path $root 'src/modules/PwshProfile.EndOfLife/PwshProfile.EndOfLife.psd1') -Force
$expectedProducts = @((Get-Command Get-EolInfo).Parameters['ProductName'].Attributes |
  Where-Object { $_ -is [Management.Automation.ValidateSetAttribute] } |
  ForEach-Object { $_.ValidValues } | Sort-Object)
$listedProducts = @(Get-EolInfo -ListProducts)
if (($listedProducts -join ',') -cne ($expectedProducts -join ',')) { throw 'Product listing differs from generated validation.' }
if ((@(Get-EolInfo -ListProducts -Like 'powershell') -join ',') -ne 'powershell') { throw 'Product filtering failed.' }
Write-Host 'PASS: independent module bump/changelog, unchanged profile/catalog, tag isolation, syntax, and product listing.'
