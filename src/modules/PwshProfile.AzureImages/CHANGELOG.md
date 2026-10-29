# PwshProfile.AzureImages changelog

## [1.0.0]

- Add regional image SKU discovery with Windows Server and dynamic Canonical Ubuntu presets.
- Discover regional Ubuntu offers and search versions using dots or underscores.
- Support custom publishers/offers, SKU filtering, and exact-SKU version listing.
- Expand discovery to catalogue-driven OS presets, custom publishers and wildcard offers.
- Add offline `-Catalog` search with a populated two-region snapshot and metadata.
- Add a deterministic JSON updater and OIDC weekly/manual module update PR workflow.
- Add pipeline-friendly Bicep image reference formatting.
- Fill the terminal width with fixed metadata columns and a trailing SKU column; prevent short early results from shrinking the table.
- Default to standard variants; `-Expanded` includes Pro/CIS/FIPS/minimal/hardened images.
- Keep Windows Pro editions visible.
- Add metadata-backed `-Arch` and `-Generation` filters and `-IncludeMetadata`.
- Include architecture and generation by default; allow explicit metadata opt-out.
- Warn and skip unresolvable latest images during metadata discovery; retain other errors.
- Seed 63 reported physical regions for completion and refresh them automatically.
- Prepare a module update PR for region-only changes as well as image changes.
- Default to released OS cycles within normal security support; exclude paid extensions.
- Respect Windows edition/LTSC deadlines and hide preview or unclassified images.
- Include current AVD and legacy EVD SKUs, plus the Office offer, under WindowsClient with Enterprise OS lifecycle filtering.
- Add `-IncludeUnsupported` independently of `-Expanded` for older or unclassified images.
- Cache live lifecycle data and refresh bundled lifecycle dates through the weekly workflow.
- Recognize SLES 16 offer names and CIQ Rocky community image releases.
- Add Flatcar discovery and verify the production stable channel through its official feed.
