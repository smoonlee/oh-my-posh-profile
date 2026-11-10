$ErrorActionPreference = 'Stop'
$tokens = $null
$parseErrors = $null
$setupAst = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $PSScriptRoot '../src/Invoke-PwshProfileSetup.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
foreach ($functionName in @('Invoke-PwshProfileUpdateCore', 'Test-PwshProfileScriptFile', 'Install-PwshProfileAtomicFile', 'Compare-PwshProfileSemanticVersion', 'Protect-PwshProfileNewerModules')) {
    $definition = $setupAst.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $functionName
        }, $true)
    . ([scriptblock]::Create($definition.Extent.Text))
}
$updateDefinition = $setupAst.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-PwshProfileUpdateCore'
    }, $true)
$artifactAssignment = $updateDefinition.Body.Find({
        param($node)
        $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -eq '$artifactNames'
    }, $true)
$artifactNames = & ([scriptblock]::Create($artifactAssignment.Right.Extent.Text))
$sourceFiles = Get-ChildItem (Join-Path $PSScriptRoot '../src') -File -Recurse
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('bundle-install-' + [guid]::NewGuid().ToString('N'))
function Get-PwshProfileLocalStorePaths {
    @{
        Root        = $script:StoreRoot
        Modules     = Join-Path $script:StoreRoot 'modules'
        Themes      = Join-Path $script:StoreRoot 'themes'
        Functions   = Join-Path $script:StoreRoot 'functions'
        Config      = Join-Path $script:StoreRoot 'config'
        VersionFile = Join-Path $script:StoreRoot 'version.json'
    }
}
function Get-CrossPlatformSupportPaths { @{ SourceRoot = $script:StoreRoot } }
function Get-PwshProfileGitHubRelease { param($Repository, [switch]$Prerelease) $script:Release }
function Save-PwshProfileReleaseAsset {
    param($Uri, $Destination)
    $script:Downloads.Add([string]$Uri)
    Copy-Item -LiteralPath $Uri -Destination $Destination
}
function Write-PwshProfileHeader { param($Title, $Subtitle) }
function Write-PwshProfileStatus { param($Stage, $Type, $Message) $script:Messages.Add($Message) }
try {
    $releaseRoot = New-Item -ItemType Directory -Path (Join-Path $testRoot 'release') -Force
    $manifest = [ordered]@{
        schemaVersion = 1
        version       = '4.0.0'
        tag           = 'v4.0.0'
        channel       = 'stable'
        repository    = 'smoonlee/oh-my-posh-profile'
        artifacts     = [ordered]@{}
    }
    foreach ($name in $artifactNames.Keys) {
        $assetName = $artifactNames[$name]
        $source = @($sourceFiles | Where-Object Name -EQ $assetName)
        if ($source.Count -ne 1) { throw "Expected one source file for $assetName." }
        $destination = Join-Path $releaseRoot $assetName
        Copy-Item -LiteralPath $source[0].FullName -Destination $destination
        if ($name -eq 'profile') {
            $content = Get-Content -LiteralPath $destination -Raw
            $content = $content -replace "(?m)^(\s*\`$script:PwshProfileVersion\s*=\s*)'[^']+'", "`${1}'4.0.0'"
            Set-Content -LiteralPath $destination -Value $content
        }
        $manifest.artifacts[$name] = [ordered]@{
            asset  = $assetName
            sha256 = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }
    $allArtifacts = $manifest.artifacts
    foreach ($scenario in @('legacy', 'complete', 'images-only', 'compute-only', 'partial', 'partial-compute', 'bad-hash', 'missing-asset', 'missing-required')) {
        $script:StoreRoot = Join-Path $testRoot $scenario
        $script:Messages = [System.Collections.Generic.List[string]]::new()
        $script:Downloads = [System.Collections.Generic.List[string]]::new()
        $manifest.artifacts = [ordered]@{}
        foreach ($name in $allArtifacts.Keys) {
            if ($scenario -eq 'legacy' -and $name -match '^azure(Images|Compute)') { continue }
            if ($scenario -eq 'images-only' -and $name -like 'azureCompute*') { continue }
            if ($scenario -eq 'compute-only' -and $name -like 'azureImages*') { continue }
            if ($scenario -eq 'partial' -and $name -eq 'azureImagesScript') { continue }
            if ($scenario -eq 'partial-compute' -and $name -eq 'azureComputeScript') { continue }
            if ($scenario -eq 'missing-required' -and $name -eq 'publicIPManifest') { continue }
            $manifest.artifacts[$name] = [ordered]@{
                asset  = $allArtifacts[$name].asset
                sha256 = $allArtifacts[$name].sha256
            }
        }
        if ($scenario -eq 'bad-hash') { $manifest.artifacts.azureImagesScript.sha256 = '0' * 64 }
        $manifestPath = Join-Path $releaseRoot 'PwshProfile.release.json'
        $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath
        $script:Release = [pscustomobject]@{
            tag_name   = 'v4.0.0'
            draft      = $false
            prerelease = $false
            assets     = @(
                [pscustomobject]@{ name = 'PwshProfile.release.json'; browser_download_url = $manifestPath }
                foreach ($name in $manifest.artifacts.Keys) {
                    if ($scenario -eq 'missing-asset' -and $name -eq 'azureImagesScript') { continue }
                    $assetName = $artifactNames[$name]
                    [pscustomobject]@{ name = $assetName; browser_download_url = Join-Path $releaseRoot $assetName }
                }
            )
        }
        $result = Invoke-PwshProfileUpdateCore -Bootstrap
        if ($scenario -in @('legacy', 'complete', 'images-only', 'compute-only')) {
            if ($result -ne $true) { throw "Fresh $scenario installation failed: $($script:Messages -join '; ')" }
            $baseline = Get-Content (Join-Path $script:StoreRoot 'version.json') -Raw | ConvertFrom-Json
            if ($baseline.artifacts.PSObject.Properties.Name.Count -ne $manifest.artifacts.Count) {
                throw "The $scenario baseline must track only published artifacts."
            }
            foreach ($name in $manifest.artifacts.Keys) {
                $installedFile = @(Get-ChildItem $script:StoreRoot -File -Recurse | Where-Object Name -EQ $artifactNames[$name])
                if ($installedFile.Count -ne 1 -or
                    (Get-FileHash $installedFile[0].FullName -Algorithm SHA256).Hash -ine $manifest.artifacts[$name].sha256) {
                    throw "Installed artifact mismatch: $scenario/$name"
                }
            }
            "PASS: fresh $scenario bundle installation verifies and tracks all published assets."
            $script:Downloads.Clear()
            if ((Invoke-PwshProfileUpdateCore) -ne $true -or $script:Downloads.Count -ne 1 -or
                $script:Messages[-1] -ne 'Already up to date.') {
                throw "The $scenario installation must not repeatedly repair unpublished modules."
            }
            "PASS: unchanged $scenario bundle does not download installed assets again."
            if ($scenario -eq 'legacy') {
                $manifest.artifacts = $allArtifacts
                $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath
                $script:Release.assets = @(
                    [pscustomobject]@{ name = 'PwshProfile.release.json'; browser_download_url = $manifestPath }
                    foreach ($name in $allArtifacts.Keys) {
                        $assetName = $artifactNames[$name]
                        [pscustomobject]@{ name = $assetName; browser_download_url = Join-Path $releaseRoot $assetName }
                    }
                )
                if ((Invoke-PwshProfileUpdateCore) -ne $true) {
                    throw "Adding newly published modules failed: $($script:Messages -join '; ')"
                }
                $baseline = Get-Content (Join-Path $script:StoreRoot 'version.json') -Raw | ConvertFrom-Json
                if ($baseline.artifacts.PSObject.Properties.Name.Count -ne $allArtifacts.Count) {
                    throw 'Newly published modules must be added to the installation baseline.'
                }
                'PASS: existing legacy installation accepts newly published module assets.'
            }
        } else {
            if ($result -ne $false -or @(Get-ChildItem $script:StoreRoot -File -Recurse).Count -ne 0) {
                throw "Invalid $scenario bundle must fail without installing files."
            }
            "PASS: $scenario bundle rejected without installing files."
        }
    }
} finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
