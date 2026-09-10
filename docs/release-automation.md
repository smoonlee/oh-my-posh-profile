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
