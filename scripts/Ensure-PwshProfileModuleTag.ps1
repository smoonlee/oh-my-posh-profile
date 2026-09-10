[CmdletBinding()]
param(
  [Parameter(Mandatory)][string] $Repository,
  [Parameter(Mandatory)][ValidatePattern('^PwshProfile\.[A-Za-z0-9_.-]+-v(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$')][string] $Tag,
  [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{40}$')][string] $Commit
)
$ErrorActionPreference = 'Stop'
# A draft release does not create its Git tag. Create it explicitly before
# packaging, including when retrying a draft left by an interrupted run.
$refs = gh api "repos/$Repository/git/matching-refs/tags/$Tag" | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw "Could not query tag $Tag." }
$existing = @($refs | Where-Object { $_.ref -ceq "refs/tags/$Tag" })
if ($existing.Count -eq 0) {
  gh api --method POST "repos/$Repository/git/refs" -f "ref=refs/tags/$Tag" -f "sha=$Commit" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Could not create tag $Tag." }
}
# Resolve through commits to support both lightweight and annotated tags.
$actualCommit = gh api "repos/$Repository/commits/$Tag" --jq .sha
if ($LASTEXITCODE -ne 0 -or $actualCommit -cne $Commit) {
  throw "Tag $Tag does not match packaged commit $Commit. Existing tags must not be moved."
}
