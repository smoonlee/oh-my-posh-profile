# Create a profile release

## v4 draft packaging workflow

Create and push the version tag first, then create a **draft** GitHub Release
using that existing tag. Run **Publish Pwsh Profile Release** manually with
`release_tag` set to that tag. The workflow resolves the tag to a commit SHA,
packages that revision, uploads assets while the release is still a draft,
downloads and verifies the uploaded hashes, then publishes the completed release.
Do not publish the draft manually before packaging. Published releases are refused;
only draft assets may be replaced during a retry. A failed published release
requires a new version, not replacement assets.

Pushing a tag alone does not run `.github/workflows/publish-profile-release.yml`.

## Release order

1. Update the embedded version in
   `src/profile/Microsoft.PowerShell_profile.ps1`.
2. Add the matching dated section to `CHANGELOG.md`.
3. Commit the release changes and push `main`.
4. Create an annotated tag on that exact commit and push the tag.
5. Create a draft GitHub Release for the tag and dispatch the packaging workflow.
6. Verify that **Publish Pwsh Profile Release** succeeds, publishes the draft, and uploads all
   twenty-one release assets.

If changes go through a pull request, merge the PR first, update local `main`
with a fast-forward pull, and tag the resulting merge commit. Never tag the
unmerged feature branch.

## GA example

For `4.0.0`, the embedded version, changelog heading, tag, and
GitHub Release must all use the exact same value.

```powershell
git switch main
git pull --ff-only origin main

# Update and validate the versioned files before continuing.
git status --short
git diff --check

# Commit and push the release commit first.
git add --all
git commit -m "Release v4.0.0"
git push origin main

# Tag the commit that is now on origin/main.
git tag -a v4.0.0 -m "Release v4.0.0"
git push origin v4.0.0

# Create the draft, then explicitly dispatch packaging.
gh release create v4.0.0 `
  --verify-tag `
  --draft `
  --title "v4.0.0" `
  --notes-from-tag
gh workflow run publish-profile-release.yml -f release_tag=v4.0.0
```

For a prerelease, use the exact prerelease SemVer everywhere and add
`--prerelease` when creating the draft.

## Verify the release

```powershell
gh run list --workflow "Publish Pwsh Profile Release" --limit 5
gh release view v4.0.0 --json isDraft,isPrerelease,tagName,url,assets
```

A successful release contains:

- `Microsoft.PowerShell_profile.ps1`
- `quick-term-cloud.omp.json`
- `Invoke-PwshProfileSetup.ps1`
- `PwshProfile.PublicIP.psd1`
- `PwshProfile.PublicIP.psm1`
- `PwshProfile.NetworkCidr.psd1`
- `PwshProfile.NetworkCidr.psm1`
- `PwshProfile.NetworkCidr.Format.ps1xml`
- `PwshProfile.EndOfLife.psd1`
- `PwshProfile.EndOfLife.psm1`
- `PwshProfile.EndOfLife.Format.ps1xml`
- `PwshProfile.AzureKubernetes.psd1`
- `PwshProfile.AzureKubernetes.psm1`
- `PwshProfile.Dns.psd1`
- `PwshProfile.Dns.psm1`
- `PwshProfile.Dns.Format.ps1xml`
- `PwshProfile.TlsCertificate.psd1`
- `PwshProfile.TlsCertificate.psm1`
- `PwshProfile.TlsCertificate.Format.ps1xml`
- `NerdFontsCatalog.json`
- `PwshProfile.release.json`

The workflow rejects a release when:

- the tag is not valid SemVer 2.0;
- the tag and embedded profile version differ;
- the GitHub prerelease setting does not match the SemVer prerelease component;
- `CHANGELOG.md` has no matching version section;
- any PowerShell script or module fails parsing;
- any optional module manifest is invalid;
- the theme is invalid JSON; or
- the release is already published, the tag moves, or uploaded asset verification fails.

## Important safeguards

- The `Validate Pwsh Profile` workflow runs the Windows regression suite on PRs,
  `main`, and merge queues. Configure `Windows regression` as a required status
  check in the GitHub ruleset protecting `main`; workflow files alone do not
  enforce merge protection. Require the branch to be up to date or use a merge queue.
- CI tests PowerShell 7 plus targeted Windows PowerShell 5.1 fallbacks. It does
  not claim full feature parity on 5.1. OMP is pinned to 31.2.0 for reproducibility;
  update the pin deliberately and rerun the prompt and initialization tests.
- Do not move or reuse a published tag.
- Do not delete and recreate a release to replace assets; increment the version.
- Confirm the workflow succeeded before announcing or installing the release.
- Prerelease installation requires `Update-PwshProfile -Prerelease`.
