# Independent module releases

Every module under `src/modules/PwshProfile.*` can be released independently
from the Pwsh Profile bundle. A module release changes only that module's
version and files; the profile version and unrelated modules remain unchanged.

Each independently released module must follow these conventions:

- Its directory and manifest are both named `PwshProfile.<Name>`.
- `RootModule` names a `.psm1` file in the same directory.
- `FormatsToProcess`, when present, names `.ps1xml` files in that directory.
- The directory contains a `CHANGELOG.md` section matching `ModuleVersion`.
- A release version is stable SemVer in the form `major.minor.patch`.

When a merged PR changes a module manifest's `ModuleVersion`, the **Publish Pwsh
Profile Module Updates** workflow discovers it automatically. It compares the
base and merged versions, reads the matching module changelog section, validates
the manifest, script, and declared format files, and creates a draft release
tagged `PwshProfile.<Name>-v<version>`. Before creating the draft, it creates
the Git tag at the merged commit and verifies it. An existing tag must resolve
to that same commit; retries never move tags. This also handles a missing tag
when retrying an unpublished draft.

Direct pushes and changes without a `ModuleVersion` bump do not trigger a module
release. Publication currently requires a PR from this repository merged into
`main`; fork PRs are excluded by the workflow guard. Module versions use stable
`major.minor.patch` numbers, independently of the profile prerelease channel.

The workflow uploads only the files declared by that module plus
`PwshProfile.<Name>.release.json`, which records their SHA-256 hashes. It
publishes the release after every asset uploads successfully. Multiple module
version changes in one PR produce separate releases. An unchanged version does
not produce a release, and a validation or upload failure leaves an unpublished
draft.

`Update-PwshProfile` queries all release pages and discovers all module tags matching
installed `PwshProfile.*` modules. For each newer version it verifies release
metadata and every asset hash, stages the complete module, validates PowerShell
and XML, replaces only that module's files atomically, and restores backups if
installation fails. Loaded modules are re-imported after installation.

Module tags are excluded from stable and prerelease profile selection. Full
profile releases continue to use `v<version>` tags and self-contained bundles.

The EndOfLife catalog workflow uses the same generic publisher. When its product
set changes, it increments `PwshProfile.EndOfLife` to the next minor version and
updates that module's changelog. It does not change the profile version.

Run `pwsh -NoProfile -File scripts/Test-ModuleReleases.ps1` to check tag creation,
draft retries, failure guards, and update discovery for every current module plus
a synthetic future module. The updater discovers names from published releases
and updates only modules already installed in the profile store.

Run `pwsh -NoProfile -File scripts/Test-EndOfLifeRelease.ps1` to verify catalog
versioning, profile/module tag isolation, and independent module installation
without network access.

## Azure image catalogue

[Update Azure Images Catalog](../.github/workflows/update-azure-images.yml) runs
Sundays at 08:00 UTC and supports manual dispatch on `main`. It refreshes
[AzureImagesCatalog.json](../AzureImagesCatalog.json) and opens a PR on
`automation/update-azure-images`; it never commits directly to `main` or deploys
Azure resources. The bundled catalogue already contains an image snapshot for
`uksouth` and `eastus`, so offline discovery does not require workflow setup.
Configuring authentication enables future refreshes; the job skips while its
required repository variables are absent.

### Authentication setup

1. Use a dedicated Entra application/service principal or user-assigned managed
   identity with read access to the Azure subscription. The built-in **Reader**
   role at subscription scope is sufficient; Contributor and Microsoft Graph API
   permissions are not required for these catalogue queries.
2. Configure a GitHub OIDC federated credential with issuer
   `https://token.actions.githubusercontent.com`, audience `api://AzureADTokenExchange`,
   and subject `repo:<owner>/<repository>:ref:refs/heads/main`. For this repository,
   the subject is `repo:smoonlee/oh-my-posh-profile:ref:refs/heads/main`.
   Restrict the credential to this repository and branch, not pull requests.
3. In repository **Settings > Secrets and variables > Actions > Variables**, set
   `AZURE_CLIENT_ID`, `AZURE_TENANT_ID` and `AZURE_SUBSCRIPTION_ID` to that identity's
   client ID, tenant ID and target subscription ID. These are identifiers, not a
   client secret. No Azure credential is stored in this repository.
4. Allow GitHub Actions to create pull requests in the repository's workflow
   permissions settings. The workflow grants its job `contents: write`,
   `pull-requests: write` and `id-token: write`; all actions are commit-pinned.
5. Dispatch **Update Azure Images Catalog** from `main`, review the generated PR,
   and merge it. The job skips until all three variables exist. Authentication or
   query failures fail the job without creating a partial catalogue update PR.

See the [Azure Login OIDC documentation](https://github.com/Azure/login#login-with-openid-connect-oidc-recommended)
for identity setup. No identities, federated credentials, role assignments or
repository variables are provisioned by this change. A real authenticated Actions
run is required to verify the selected tenant/subscription configuration.

### Refresh behaviour

The JSON catalogue configures snapshot `Locations` (initially `uksouth` and
`eastus`) and OS, publisher and offer-pattern mappings. Separately,
`AvailableLocations` stores all physical-region names returned by
`az account list-locations` for the workflow subscription. It drives both modules' location
completion and starts with 63 names read from Azure, including restricted or preview
regions that are not necessarily deployable. New names trigger the same update PR
and independent patches for both modules even if images are unchanged. They do not automatically expand
the expensive image snapshot scan; edit `Locations` deliberately to do that.
The catalogue targets public `AzureCloud`; the updater
rejects a different active CLI cloud. Other-cloud queries can still use the module's
live publisher discovery, but the bundled catalogue is not a sovereign-cloud index.

The updater discovers available publishers in each region and enumerates matching
offers and SKUs with `-Expanded -IncludeMetadata -IncludeUnsupported`. This retains Pro/CIS and other
specialised variants for opt-in searches and records Azure-reported architecture
and Hyper-V generation. Metadata adds one details request per candidate, and the
workflow has a 120-minute timeout. Missing publishers are reported and skipped. It does not enumerate
every image version, accept purchase terms, inspect your deployed VMs, or check
quota, price, capacity or image/VM compatibility. All entries use the unresolved
`latest` version alias. New releases matching an existing mapping are discovered
automatically; entirely new vendors/OS families require a reviewed mapping change.

The updater also retrieves validated lifecycle records from endoflife.date and
the official Flatcar stable-channel feed, then
embeds them as `Lifecycles` (product, cycle, release date and normal EOL date).
Paid extension deadlines are deliberately not used. Supported-only queries use
those records offline and current, hourly-cached lifecycle data for live searches.
The image snapshot retains older releases for `-IncludeUnsupported`; expiry is
evaluated at query time rather than permanently removing them from the snapshot.
Lifecycle-only changes prepare a module update PR even when images are unchanged.
Lifecycle HTTP failures or invalid dates stop the update before any files are written.

Queries must finish successfully before files are written. Empty or malformed
region lists, empty snapshot regions, removal of any previously reported physical
region or lifecycle record, and removal of more than 25% of image entries stop the refresh. After investigating
an expected removal, manually dispatch with `allow_large_removal` enabled; normal
scheduled runs cannot enable it. Diff review remains required for smaller removals
and for publisher/offer classification. Entries are sorted and no refresh timestamp
is written, so identical data does not produce repeated PRs or version bumps.

The script embeds the validated JSON in the module, keeping both bundle and
independent module releases self-contained without a separate JSON runtime asset.
The module's wrapped table view is a declared `.Format.ps1xml` asset, included in
both the full bundle and independent releases. Install a new full bundle (or use
local setup) first when upgrading an installation that does not track that file.
Semantic changes prepare the next `PwshProfile.AzureImages` patch version and its
changelog. Existing independent-release automation publishes it when the PR merges.
Region changes additionally prepare a `PwshProfile.AzureCompute` patch and embed
the updated completion list in that module, without a runtime dependency on Images.
Image-only and lifecycle-only changes leave Compute's version unchanged.
The profile version and unrelated modules are unchanged. Git history records snapshot
changes; `-Catalog` is discovery data, not a claim of current regional availability.

For a local refresh using an already signed-in Azure CLI:

```powershell
./scripts/Update-AzureImagesCatalog.ps1 -Subscription '<subscription-id>' -PrepareRelease
Import-Module ./src/modules/PwshProfile.AzureImages/PwshProfile.AzureImages.psd1 -Force
Get-AzureVmImage -Catalog -Search 26.04
Get-AzureVmImage -Location uksouth -OS Ubuntu -Search 26.04
```

After intentionally editing catalogue mappings without a live refresh, use
`./scripts/Update-AzureImagesCatalog.ps1 -EmbedOnly -PrepareRelease` to validate and
embed the edited catalogue. Existing entries must still match its mappings.
This mode makes no Azure calls and does not populate missing images.
It also validates existing lifecycle records without contacting endoflife.date.

`scripts/Test-AzureDiscovery.ps1` exercises live discovery with mocked Azure CLI,
offline catalogue queries, wrapped output at 80/120 columns, standard/expanded
variants, platform metadata filters, physical-region discovery, region-only PR
preparation, cloud mismatch, query failure, large removals, deterministic output,
version preparation and local installation.
It runs in CI on PowerShell 7 and Windows PowerShell 5.1. The refresh workflow also
runs the image tests and independent module release checks before opening a PR.

## v4 update safety and limits

Independent updates may replace only files already tracked in the installed
bundle's `version.json`. Introducing a new module or format file requires a full
profile bundle first; v4 does not migrate the artifact schema during an independent
update. Local edits cause updates to stop instead of being silently overwritten.
Successful independent updates refresh the bundle baseline. Subsequent bundle
updates preserve a newer independently installed module when its hashes still
match that baseline; a bundle with a newer module version can upgrade it.

Bundle and module transactions share an exclusive `update.lock` in the local
profile store. The lock file remaining on disk is normal: the open file handle,
not the file's existence, prevents concurrent updates.

Before each replacement, the updater records original content in a `.recovery`
backup and writes `update-journal.json`. A successful transaction clears the
journal; an interrupted transaction blocks further updates for manual recovery.
Close other updating sessions, preserve any edits made since the interruption,
and inspect each journal entry. For `existed: true`, copy its `backup` to its
`destination`; for `existed: false`, remove only that newly created destination.
Verify every entry before removing the journal and retrying. Do not simply delete
the journal to bypass recovery. Recovery backups are retained for inspection and
can be removed manually after verifying a working installation.

PowerShell 7 on Windows is the fully regression-tested runtime. Windows PowerShell
5.1 has targeted startup/fallback checks only; Azure CLI argument completion is
disabled there. Module manifests' minimum versions do not imply full end-to-end
5.1 support. A clean-machine setup and hosted Actions run remain release gates.
