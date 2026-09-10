$ErrorActionPreference = 'Stop'
$profilePath = Join-Path $PSScriptRoot '../src/profile/Microsoft.PowerShell_profile.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
  $profilePath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
$functionAst = $ast.Find({
  param($node)
  $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
  $node.Name -eq 'global:Update-PwshProfilePoshIdleLayout'
}, $true)
if (-not $functionAst) { throw 'Resize function missing.' }

$installerAst = $ast.Find({
  param($node)
  $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
  $node.Name -eq 'Install-PwshProfilePoshContext'
}, $true)
. ([scriptblock]::Create($installerAst.Extent.Text))
$script:WidthHookCalls = 0
function global:Update-PwshProfilePoshTerminalWidth { $script:WidthHookCalls++ }
$testModule = New-Module {
  $script:ContextCalls = 0
  function Set-PoshContext { param($status) $script:ContextCalls++ }
  function Test-Prompt {
    $status = $?
    Set-PoshContext $status
    [pscustomobject]@{ Status = $status; ContextCalls = $script:ContextCalls }
  }
  Export-ModuleMember -Function Test-Prompt
}
try {
  $originalPrompt = & $testModule { ${function:Test-Prompt} }
  Install-PwshProfilePoshContext -Module $testModule
  Install-PwshProfilePoshContext -Module $testModule
  $currentPrompt = & $testModule { ${function:Test-Prompt} }
  if ($originalPrompt -ne $currentPrompt) { throw 'Context installation replaced prompt.' }
  $result = & $testModule {
    Write-Error 'Simulated failed command' -ErrorAction SilentlyContinue
    Test-Prompt
  }
  if ($result.Status -or $result.ContextCalls -ne 1 -or $script:WidthHookCalls -ne 1) {
    throw 'Context hook lost failed status or duplicated a callback.'
  }
  'PASS: failed command status preserved, existing context retained, hook reload does not recurse.'
}
finally {
  Remove-Module $testModule -Force
  Remove-Item Function:/Update-PwshProfilePoshTerminalWidth
}

# Exercise the production handler with a fake console and line editor, without
# repainting the terminal running this test or loading the rest of the profile.
Add-Type @'
public static class PoshResizeTestEditor {
    public static string Line = "";
    public static int Redraws;
    public static bool Fail;
    public static void GetBufferState(ref string line, ref int cursor) {
        line = Line; cursor = Line.Length;
    }
    public static void InvokePrompt() {
        Redraws++;
        if (Fail) throw new System.InvalidOperationException("No console");
    }
}
'@
$source = $functionAst.Extent.Text.Replace('$Host.', '$script:ResizeTestHost.').Replace(
  '[Microsoft.PowerShell.PSConsoleReadLine]', '[PoshResizeTestEditor]')
. ([scriptblock]::Create($source))
$script:ResizeTestHost = @{ UI = @{ RawUI = @{ WindowSize = @{ Width = 120 } } } }
$previousWidth = $env:POSH_TERMINAL_WIDTH
try {
  $env:POSH_TERMINAL_WIDTH = '120'
  Update-PwshProfilePoshIdleLayout
  if ([PoshResizeTestEditor]::Redraws -ne 0) { throw 'Unchanged width repainted.' }
  $script:ResizeTestHost.UI.RawUI.WindowSize.Width = 100
  [PoshResizeTestEditor]::Line = 'Get-Item '
  Update-PwshProfilePoshIdleLayout
  if ([PoshResizeTestEditor]::Redraws -ne 0 -or $env:POSH_TERMINAL_WIDTH -ne '120') {
    throw 'Typed input was not deferred.'
  }
  [PoshResizeTestEditor]::Line = ''
  Update-PwshProfilePoshIdleLayout
  Update-PwshProfilePoshIdleLayout
  if ([PoshResizeTestEditor]::Redraws -ne 1 -or $env:POSH_TERMINAL_WIDTH -ne '100') {
    throw 'Resize did not repaint exactly once.'
  }
  $script:ResizeTestHost.UI.RawUI.WindowSize.Width = 0
  Update-PwshProfilePoshIdleLayout
  if ([PoshResizeTestEditor]::Redraws -ne 1) { throw 'Invalid width repainted.' }
  $script:ResizeTestHost.UI.RawUI.WindowSize.Width = 140
  [PoshResizeTestEditor]::Fail = $true
  Update-PwshProfilePoshIdleLayout
  Update-PwshProfilePoshIdleLayout
  if ([PoshResizeTestEditor]::Redraws -ne 2) { throw 'Failed redraw was retried.' }
  'PASS: profile syntax, resize, unchanged width, typed input, invalid width, redraw failure.'

  $cleanup = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.PipelineAst] -and
    $node.Extent.Text.StartsWith('Get-EventSubscriber -SourceIdentifier PowerShell.OnIdle')
  }, $true)
  $registration = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.IfStatementAst] -and
    $node.Extent.Text.StartsWith('if (Get-Command PSConsoleHostReadLine')
  }, $true)
  function global:PSConsoleHostReadLine { }
  $otherJob = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MessageData 'ResizeTest.Other' -Action { }
  $otherJob.Name = 'ResizeTest.Other'
  try {
    1..2 | ForEach-Object {
      . ([scriptblock]::Create($cleanup.Extent.Text))
      . ([scriptblock]::Create($registration.Extent.Text))
    }
    $subscriptions = @(Get-EventSubscriber -SourceIdentifier PowerShell.OnIdle)
    if (@($subscriptions | Where-Object { $_.Action.Name -eq 'PwshProfile.PoshResize' }).Count -ne 1) {
      throw 'Profile reload duplicated the resize subscription.'
    }
    if (@($subscriptions | Where-Object { $_.Action.Name -eq 'ResizeTest.Other' }).Count -ne 1) {
      throw 'Profile reload removed another idle handler.'
    }
    'PASS: real event registration, reload deduplication, unrelated idle handler retained.'
  }
  finally {
    . ([scriptblock]::Create($cleanup.Extent.Text))
    Get-EventSubscriber -SourceIdentifier PowerShell.OnIdle |
      Where-Object { $_.Action.Name -eq 'ResizeTest.Other' } |
      ForEach-Object { Unregister-Event -SubscriptionId $_.SubscriptionId }
    Remove-Job -Job $otherJob -Force
    Remove-Item Function:/PSConsoleHostReadLine
  }
}
finally {
  $env:POSH_TERMINAL_WIDTH = $previousWidth
  Remove-Item Function:/Update-PwshProfilePoshIdleLayout
}
