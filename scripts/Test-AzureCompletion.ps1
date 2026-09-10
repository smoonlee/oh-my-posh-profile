$ErrorActionPreference = 'Stop'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
  (Join-Path $PSScriptRoot '../src/profile/Microsoft.PowerShell_profile.ps1'),
  [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
$helper = $ast.Find({
  param($node)
  $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
  $node.Name -eq 'global:Invoke-PwshProfileCompletionProcess'
}, $true)
. ([scriptblock]::Create($helper.Extent.Text))

function New-TestCompletionStartInfo([string]$Code) {
  $info = [System.Diagnostics.ProcessStartInfo]::new()
  $info.FileName = (Get-Process -Id $PID).Path
  $info.UseShellExecute = $false
  $info.CreateNoWindow = $true
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  foreach ($arg in @('-NoLogo', '-NoProfile', '-NonInteractive', '-EncodedCommand',
      [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Code)))) {
    $info.ArgumentList.Add($arg)
  }
  $info
}

try {
  $info = New-TestCompletionStartInfo '[Console]::Out.Write("x" * 1048576); [Console]::Error.Write("e" * 1048576); exit 0'
  if (-not (Invoke-PwshProfileCompletionProcess $info -TimeoutMilliseconds 5000)) {
    throw 'Large output blocked completion or caused failure.'
  }
  $info = New-TestCompletionStartInfo 'exit 7'
  if (Invoke-PwshProfileCompletionProcess $info -TimeoutMilliseconds 5000) {
    throw 'Failed completion was accepted.'
  }
  $info = New-TestCompletionStartInfo 'Start-Sleep -Seconds 30'
  $timer = [Diagnostics.Stopwatch]::StartNew()
  if (Invoke-PwshProfileCompletionProcess $info -TimeoutMilliseconds 500) {
    throw 'Timed-out completion was accepted.'
  }
  if ($timer.Elapsed.TotalSeconds -gt 3) { throw 'Timeout cleanup took too long.' }
  $info.FileName = Join-Path $PSScriptRoot 'missing-completion-test-executable.exe'
  if (Invoke-PwshProfileCompletionProcess $info) { throw 'Missing executable was accepted.' }
  'PASS: large stdout/stderr, failed exit, bounded timeout, missing executable.'

  $pidFile = New-TemporaryFile
  try {
    $escapedPidFile = $pidFile.FullName.Replace("'", "''")
    $code = @'
$info = [Diagnostics.ProcessStartInfo]::new()
$info.FileName = (Get-Process -Id $PID).Path
$info.UseShellExecute = $false
$info.CreateNoWindow = $true
foreach ($arg in @('-NoProfile', '-NonInteractive', '-Command', 'Start-Sleep -Seconds 30')) {
  $info.ArgumentList.Add($arg)
}
$child = [Diagnostics.Process]::Start($info)
[IO.File]::WriteAllText('__PID_FILE__', "$PID,$($child.Id)")
Start-Sleep -Seconds 30
'@
    $info = New-TestCompletionStartInfo ($code.Replace('__PID_FILE__', $escapedPidFile))
    if (Invoke-PwshProfileCompletionProcess $info -TimeoutMilliseconds 3000) {
      throw 'Sleeping process tree was accepted.'
    }
    $ids = @((Get-Content -LiteralPath $pidFile.FullName -Raw).Trim().Split(',') | ForEach-Object { [int]$_ })
    if ($ids.Count -ne 2 -or $ids -contains 0) { throw 'Test child did not start.' }
    Start-Sleep -Milliseconds 200
    foreach ($processId in $ids) {
      if (Get-Process -Id $processId -ErrorAction Ignore) { throw 'Timeout left a child process running.' }
    }
    'PASS: timeout terminates both parent and child processes.'
  }
  finally {
    Remove-Item -LiteralPath $pidFile.FullName -Force
  }
}
finally {
  Remove-Item Function:/Invoke-PwshProfileCompletionProcess
}
