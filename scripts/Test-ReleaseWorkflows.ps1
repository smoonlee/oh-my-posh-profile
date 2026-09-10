$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$blocks = @{}
foreach ($file in Get-ChildItem (Join-Path $root '.github/workflows') -Filter '*.yml') {
  $lines = Get-Content $file.FullName
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -notmatch '^(\s*)run: \|\s*$') { continue }
    $indent = $Matches[1].Length
    $body = [Collections.Generic.List[string]]::new()
    for ($i++; $i -lt $lines.Count; $i++) {
      if ($lines[$i].Trim() -and ($lines[$i].Length - $lines[$i].TrimStart().Length) -le $indent) { $i--; break }
      $body.Add($lines[$i])
    }
    $code = ($body -join "`n") -replace '\$\{\{.*?\}\}', 'test/repository'
    $tokens = $null; $errors = $null
    [void][Management.Automation.Language.Parser]::ParseInput($code, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw "$($file.Name): $($errors.Message -join '; ')" }
    if ($code -like '*Release must remain a draft*') { $blocks.ProfilePublish = $code }
  }
}
'PASS: embedded PowerShell syntax in all workflows.'
if (-not $blocks.ProfilePublish) { throw 'Profile verification block missing.' }
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('release-test-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $testRoot
$oldEnv = @{}
foreach ($name in @('RUNNER_TEMP','assetRoot','RELEASE_TAG','RELEASE_REF','RELEASE_PRERELEASE','GITHUB_REPOSITORY')) { $oldEnv[$name] = [Environment]::GetEnvironmentVariable($name) }
function gh {
  $global:LASTEXITCODE = 0
  switch ($args[0]) {
    'api' { if ($script:Scenario -eq 'moved') { 'different-commit' } else { $env:RELEASE_REF } }
    'release' {
      switch ($args[1]) {
        'view' { @{ isDraft = ($script:Scenario -ne 'published'); assets = @() } | ConvertTo-Json }
        'download' {
          if ($script:Scenario -eq 'download-failure') { $global:LASTEXITCODE = 1; return }
          $destination = $args[4]
          if ($script:Scenario -ne 'missing') { Copy-Item (Join-Path $env:assetRoot 'asset.txt') $destination }
          if ($script:Scenario -eq 'corrupt') { Set-Content (Join-Path $destination 'asset.txt') 'corrupt' }
        }
        'edit' { $script:Published = $true }
        default { throw 'Unexpected gh command' }
      }
    }
    default { throw 'Unexpected gh command' }
  }
}
try {
  $env:RELEASE_TAG = 'v4.0.0-test'; $env:RELEASE_REF = 'a' * 40
  $env:RELEASE_PRERELEASE = 'true'; $env:GITHUB_REPOSITORY = 'test/repository'
  foreach ($scenario in @('valid','published','moved','missing','corrupt','download-failure')) {
    $script:Scenario = $scenario; $script:Published = $false
    $env:RUNNER_TEMP = Join-Path $testRoot $scenario
    $env:assetRoot = Join-Path $env:RUNNER_TEMP 'assets'
    $null = New-Item -ItemType Directory -Path $env:assetRoot -Force
    Set-Content (Join-Path $env:assetRoot 'asset.txt') 'verified content'
    $failed = $false
    try { & ([scriptblock]::Create($blocks.ProfilePublish)) } catch { $failed = $true }
    if ($scenario -eq 'valid') {
      if ($failed -or -not $script:Published) { throw 'Valid draft did not publish.' }
    } elseif (-not $failed -or $script:Published) { throw "Unsafe publication in scenario $scenario" }
    "PASS: profile publication scenario $scenario"
  }
} finally {
  foreach ($name in $oldEnv.Keys) { [Environment]::SetEnvironmentVariable($name, $oldEnv[$name]) }
  # Only synthetic files created inside this uniquely named test directory.
  Get-ChildItem $testRoot -Recurse -File | Remove-Item -Force
  Get-ChildItem $testRoot -Recurse -Directory | Sort-Object FullName -Descending | Remove-Item
  Remove-Item $testRoot
}
