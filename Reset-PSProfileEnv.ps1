<#
.NAME 
    Reset-PSProfileEnv.ps1

.AUTHOR
    Simon Lee
    @smoon_lee

.CHANGELOG
    2022-01-11 - Inital Script Created - version: 1.0
    2022-01-11 - Refactor Code with Logic - version: 1.1
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

# Remove Powershell Modules - Oh-My-Posh - PowerShell 5
if (Test-Path -Path 'C:\Program Files\WindowsPowerShell\Modules\Oh-My-Posh' -ErrorAction SilentlyContinue) {
    if ((Get-Item -Path 'C:\Program Files\PowerShell\WindowsModules\Oh-My-Posh' -ErrorAction SilentlyContinue).LinkType -like 'SymbolicLink') {
        (Get-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Oh-My-Posh' -ErrorAction SilentlyContinue).Delete()
        Write-Warning -Message 'PowerShell 5 | Oh-My-Posh Removed'
    }
    Else {
        Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Oh-My-Posh' -Force -Recurse
        Write-Warning -Message 'PowerShell 5 | Oh-My-Posh Removed'
    }
}
else {
    Write-Warning -Message 'PowerShell 5 | Oh-My-Posh not Installed.'
}

# Remove Powershell Modules - Oh-My-Posh - PowerShell 7
if (Test-Path -Path 'C:\Program Files\PowerShell\Modules\Oh-My-Posh' -ErrorAction SilentlyContinue) {
    if ((Get-Item -Path 'C:\Program Files\PowerShell\Modules\Oh-My-Posh' -ErrorAction SilentlyContinue).LinkType -like 'SymbolicLink') {
        (Get-Item -Path 'C:\Program Files\PowerShell\Modules\Oh-My-Posh' -ErrorAction SilentlyContinue).Delete()
        Write-Warning -Message 'PowerShell 7 | Oh-My-Posh Removed'
    }
    Else {
        Remove-Item -Path 'C:\Program Files\PowerShell\Modules\Oh-My-Posh' -Force -Recurse
        Write-Warning -Message 'PowerShell 7 | Oh-My-Posh Removed'
    }
}
else {
    Write-Warning -Message 'PowerShell 7 | Oh-My-Posh not Installed.'
}

Write-Output ''
# Remove Powershell Modules - Posh-Git - PowerShell 5
if (Test-Path -Path 'C:\Program Files\WindowsPowerShell\Modules\Posh-Git' -ErrorAction SilentlyContinue) {
    if ((Get-Item -Path 'C:\Program Files\PowerShell\WindowsModules\Posh-Git' -ErrorAction SilentlyContinue).LinkType -like 'SymbolicLink') {
        (Get-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Posh-Git' -ErrorAction SilentlyContinue).Delete()
        Write-Warning -Message 'PowerShell 5 | Posh-Git Removed'
    }
    Else {
        Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Posh-Git' -Force -Recurse
        Write-Warning -Message 'PowerShell 5 | Posh-Git Removed'
    }
}
else {
    Write-Warning -Message 'PowerShell 5 | Posh-Git not Installed.'
}

# Remove Powershell Modules - Posh-Git - PowerShell 7
if (Test-Path -Path 'C:\Program Files\PowerShell\Modules\Posh-Git' -ErrorAction SilentlyContinue) {
    if ((Get-Item -Path 'C:\Program Files\PowerShell\Modules\Posh-Git' -ErrorAction SilentlyContinue).LinkType -like 'SymbolicLink') {
        (Get-Item -Path 'C:\Program Files\PowerShell\Modules\Posh-Git' -ErrorAction SilentlyContinue).Delete()
        Write-Warning -Message 'PowerShell 7 | Posh-Git Removed'
    }
    Else {
        Remove-Item -Path 'C:\Program Files\PowerShell\Modules\Posh-Git' -Force -Recurse
        Write-Warning -Message 'PowerShell 7 | Posh-Git Removed'
    }
}
else {
    Write-Warning -Message 'PowerShell 7 | Posh-Git not Installed.'
}

Write-Output ''
# Remove Powershell Modules - PSReadLine\2.2.0 - PowerShell 5
if (Test-Path -Path 'C:\Program Files\WindowsPowerShell\Modules\PSReadLine\2.2.0' -ErrorAction SilentlyContinue) {
    if ((Get-Item -Path 'C:\Program Files\PowerShell\WindowsModules\PSReadLine\2.2.0' -ErrorAction SilentlyContinue).LinkType -like 'SymbolicLink') {
        (Get-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\PSReadLine\2.2.0' -ErrorAction SilentlyContinue).Delete()
        Write-Warning -Message 'PowerShell 5 | PSReadLine (2.2.0) Removed'
    }
    Else {
        Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\PSReadLine\2.2.0' -Force -Recurse
        Write-Warning -Message 'PowerShell 5 | PSReadLine (2.2.0) Removed'
    }
}
else {
    Write-Warning -Message 'PowerShell 5 | PSReadLine (2.2.0) not Installed.'
}

# Remove Powershell Modules - PSReadLine\2.2.0 - PowerShell 7
if (Test-Path -Path 'C:\Program Files\PowerShell\Modules\PSReadLine\2.2.0' -ErrorAction SilentlyContinue) {
    if ((Get-Item -Path 'C:\Program Files\PowerShell\Modules\PSReadLine\2.2.0' -ErrorAction SilentlyContinue).LinkType -like 'SymbolicLink') {
        (Get-Item -Path 'C:\Program Files\PowerShell\Modules\PSReadLine\2.2.0' -ErrorAction SilentlyContinue).Delete()
        Write-Warning -Message 'PowerShell 7 | PSReadLine (2.2.0) Removed'
    }
    Else {
        Remove-Item -Path 'C:\Program Files\PowerShell\Modules\PSReadLine\2.2.0' -Force -Recurse
        Write-Warning -Message 'PowerShell 7 | PSReadLine (2.2.0) Removed'
    }
}
else {
    Write-Warning -Message 'PowerShell 7 | PSReadLine (2.2.0) not Installed.'
}

# Script Clean
Write-Output ''
Write-Output '=============================================='
Write-Output '                                              '
Write-Output '          PSProfile Modules Cleared!          '
Write-Output '=============================================='
