<#
.NAME 
    Reset-PSProfileEnv.ps1

.AUTHOR
    Simon Lee
    @smoon_lee

.CHANGELOG
    2022-01-11 - Inital Script Created - version: 1.0
#>

Write-Output '=============================================='
Write-Output '                                              '
Write-Output '       Resetting PSProfile Environment        '
Write-Output '=============================================='


Write-Warning -Message 'This will force remove PSProfile Modules:'
Write-Warning -Message 'Oh-My-Posh, Posh-Git, PSReadLines (2.2.0)'
Write-Output 'Press any key to continue...';
Write-Output ''
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

# Remove Powershell Modules - Oh-My-Posh
if (Get-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Oh-My-Posh' -ErrorAction SilentlyContinue) {
    Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Oh-My-Posh' -Force -Recurse | Out-Null
    Write-Warning -Message 'Oh-My-Posh Removed!'
}
Else {
    Write-Warning -Message 'PowerShell 5 | Oh-My-Posh Not Installed!'
}

if (Get-Item -Path 'C:\Program Files\PowerShell\Modules\Oh-My-Posh' -ErrorAction SilentlyContinue) {
    Remove-Item -Path 'C:\Program Files\PowerShell\Modules\Oh-My-Posh' -Force -Recurse | Out-Null
    Write-Warning -Message 'Oh-My-Posh Removed!'
}
Else {
    Write-Warning -Message 'PowerShell 7 | Oh-My-Posh Not Installed!'
}

Write-Output ''
# Remove Powershell Modules - Posh-Git 
if (Get-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Posh-Git' -ErrorAction SilentlyContinue) {
    Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Posh-Git' -Force -Recurse | Out-Null
    Write-Warning -Message 'Posh-Git Removed!'
}
Else {
    Write-Warning -Message 'PowerShell 5 | Posh-Git Not Installed!'
}

if (Get-Item -Path 'C:\Program Files\PowerShell\Modules\Posh-Git' -ErrorAction SilentlyContinue) {
    Remove-Item -Path 'C:\Program Files\PowerShell\Modules\Posh-Git' -Force -Recurse | Out-Null
    Write-Warning -Message 'Posh-Git Removed!'
}
Else {
    Write-Warning -Message 'PowerShell 7 | Posh-Git Not Installed!'
}

Write-Output ''
# Remove Powershell Modules - PSReadLine (2.2.0)
if (Get-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\PSReadLine\2.2.0' -ErrorAction SilentlyContinue) {
    Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\PSReadLine\2.2.0' -Force -Recurse | Out-Null
    Write-Warning -Message 'PSReadLine (2.2.0) Removed!'
}
Else {
    Write-Warning -Message 'PowerShell 5 | PSReadLine (2.2.0) Not Installed!'
}

if (Get-Item -Path 'C:\Program Files\PowerShell\Modules\PSReadLine\2.2.0' -ErrorAction SilentlyContinue) {
    Remove-Item -Path 'C:\Program Files\PowerShell\Modules\PSReadLine\2.2.0' -Force -Recurse | Out-Null
    Write-Warning -Message 'PSReadLine (2.2.0) Removed!'
}
Else {
    Write-Warning -Message 'PowerShell 7 | PSReadLine (2.2.0) Not Installed!'
}

# End
Write-Output ''
Write-Warning 'PSProfile Cleanup Completed!'