# Oh My Posh PowerShell Profile

A release-managed PowerShell 7 profile for Windows Terminal, built around
[Oh My Posh](https://ohmyposh.dev/) and a practical developer toolchain.

Version 4 adds verified installs and updates, automatic Windows Terminal setup,
dynamic Nerd Font support, and optional modules for networking, Azure Kubernetes,
DNS, lifecycle data, public IP lookups, and TLS certificates.

## Highlights

- Configures PowerShell 7, Windows PowerShell 5.1, Command Prompt, and Azure
  Cloud Shell profiles in Windows Terminal.
- Installs or updates any supported Nerd Font from the maintained catalog.
- Installs a curated CLI toolchain through Winget.
- Uses a responsive Oh My Posh theme with Git, cloud, Kubernetes, execution-time,
  clock, and GitHub Copilot usage segments.
- Checks for profile updates without delaying shell startup.
- Verifies every release asset with SHA-256 before changing local files.
- Detects local drift and uses backups, atomic replacement, and rollback.
- Keeps additional PowerShell tools disabled until you opt in.

## Requirements

- Windows 10 or Windows 11
- PowerShell 7
- Windows Terminal
- Winget for the optional package-installation phase
- Internet access during installation and update checks

Administrator access is requested only when a system-wide Nerd Font or
machine-scoped Winget package needs to be installed or updated.

## Install

> [!IMPORTANT]
> Please execute as Adminsitrator, For NerdFont Installation.

Download the setup script from the latest published release, then run it from
PowerShell 7:

```powershell
$setup = Join-Path $HOME 'Downloads\Invoke-PwshProfileSetup.ps1'
Invoke-WebRequest `
  'https://github.com/smoonlee/oh-my-posh-profile/releases/latest/download/Invoke-PwshProfileSetup.ps1' `
  -OutFile $setup
& $setup -NerdFont CaskaydiaCove
```

The default `All` phase configures the selected Nerd Font, developer packages,
PowerShell modules, Windows Terminal, and the profile. Use any friendly font name
from the [Nerd Fonts downloads page](https://www.nerdfonts.com/font-downloads);
`-NerdFont` and `-nerdFontName` are equivalent.

To install only the profile and its bundled tools:

```powershell
& $setup -RunPhase Profile
```

Available phases are `All`, `NerdFont`, `Winget`, `Modules`, `Profile`, and
`ProfileUpdate`.

> [!IMPORTANT]
> Download the installer from a GitHub Release, not from the repository branch.
> Runtime files are sourced only from an immutable published release. The
> installer does not fall back to `main`.

## What gets configured

### Windows Terminal and Nerd Fonts

The installer checks system and per-user Windows font directories before making
changes. Missing fonts are installed system-wide; tracked fonts are updated when
their Nerd Fonts release or upstream font version changes. Existing fonts with
unknown provenance are left untouched, and tracked fonts are never downgraded.

When a font is available, Windows Terminal stable and preview are updated with:

- the selected font at size `9`;
- the `Solarized Dark (modified)` colour scheme;
- managed profiles ordered as `Pwsh 7`, `Pwsh 5`, `Command Prompt`, then
  `Azure Cloud Shell`; and
- duplicate managed profiles removed without disturbing unrelated profiles.

A timestamped `.bak` file is written beside each Terminal settings file before
it is changed. The installer also prints the exact font-family value to use in
VS Code's `editor.fontFamily` and `terminal.integrated.fontFamily` settings.

### Developer CLI packages

The Winget phase installs or upgrades this toolchain:

| Package | Scope |
| --- | --- |
| AWS CLI | Machine |
| Azure CLI and Kubelogin | Machine |
| Git and GitHub CLI | Machine |
| GitHub Copilot CLI | Machine |
| Helm and kubectl | Machine |
| jq and yq | Machine |
| OpenSSL | Machine |
| PowerShell 7 | Machine |
| Speedtest CLI | Machine |
| Terraform | Machine |
| Bicep | User |
| Oh My Posh | User |

### PowerShell profile

The profile provides Git-aware prompt rendering, Azure/AWS/Kubernetes context,
command completion, history and PSReadLine configuration, profile management,
and opt-in utility modules. Prompt width is recalculated before every render, so
the Copilot usage segment switches between compact and detailed layouts as the
terminal is resized.

The profile, theme, updater, and optional modules are installed as one verified
bundle. Their version and hashes are recorded in
`%APPDATA%\PwshProfile\version.json`.

## Profile commands

```powershell
# Show installed version, update channel, and optional-module status
Get-PwshProfile

# Show installed and cached release versions
Get-PwshProfileVersion

# Check for and install available updates
Update-PwshProfile

# Select preview updates
Set-PwshProfile -EnablePreReleaseUpdate

# Return to stable updates
Set-PwshProfile -EnableReleaseUpdate
```

Stable updates are the default. A lightweight background check runs at most once
per day and caches its result; it never blocks profile startup. Updates remain
manual and refuse to overwrite locally modified or missing tracked files.

For a one-off preview update without changing the saved channel:

```powershell
Update-PwshProfile -Prerelease
```

## Optional modules

Optional modules are installed with the profile but disabled by default. Enable
or disable one with `Set-PwshProfile`; changes apply immediately in the current
session.

| Module | Enable command | Main commands |
| --- | --- | --- |
| Public IP | `Set-PwshProfile -EnablePublicIP` | `Get-PublicIP` |
| Network CIDR | `Set-PwshProfile -EnableNetworkCidr` | `Get-NetworkCidr` |
| End-of-life data | `Set-PwshProfile -EnableEndOfLife` | `Get-EolInfo` |
| Azure Kubernetes | `Set-PwshProfile -EnableAzureKubernetes` | `Get-AksVersion` |
| Azure images | `Set-PwshProfile -EnableAzureImages` | `Get-AzureVmImage`, `ConvertTo-AzureVmImageBicep` |
| Azure compute | `Set-PwshProfile -EnableAzureCompute` | `Get-AzureVmSize` |
| DNS | `Set-PwshProfile -EnableDns` | `Get-DnsResult` |
| TLS certificates | `Set-PwshProfile -EnableTlsCertificate` | `Get-TlsCertificate`, `Split-PfxCertificate`, `New-PfxCertificate`, `Test-CertificateKeyMatch`, `New-SelfSignedTlsCertificate` |

Disable a module by passing `$false` to its switch:

```powershell
Set-PwshProfile -EnableDns:$false
```

### Module updates

Azure Images and Azure Compute have independent module versions and GitHub
releases, like the other optional modules. Run the normal updater to install
newer versions of modules already installed in the profile store:

```powershell
Update-PwshProfile
Get-PwshProfile
```

Module-only updates do not change the profile version, unrelated modules or
your enable/disable settings. Loaded modules are re-imported after an update.
The updater verifies the release metadata and file hashes, installs the complete
module including its declared table-format files, and rolls back on failure.
Locally modified or missing tracked files still block replacement.

Independent releases update **existing installations**; they do not add new
modules or new `Set-PwshProfile` switches to an older profile. To use Azure Images
and Azure Compute through the profile for the first time, install a profile
bundle containing them (or use the documented local-source setup), then enable
them with the commands above. Publishing these two module releases alone does
not publish a new profile bundle.

For standalone use outside the profile, download the `.psd1`, `.psm1` and
declared `.Format.ps1xml` assets from the corresponding module release into the
same directory, then import its `.psd1`. Standalone copies outside the profile
store are not managed by `Update-PwshProfile`.

Module release tags use `PwshProfile.AzureImages-v<version>` and
`PwshProfile.AzureCompute-v<version>`, separately from profile `v<version>` tags.
See [independent module releases](docs/release-automation.md) for publication and
verification details. Catalogue refresh automation is optional and is not
required to install these modules, use live discovery or request PAYG estimates.

### Examples

```powershell
# Public address and provider details
Get-PublicIP

# Azure-aware subnet information
Get-NetworkCidr -Cidr 10.20.0.0/24 -Provider Azure

# Select one child subnet without generating the entire range
Get-NetworkCidr 10.20.0.0/16 -SplitPrefix 28 -SubnetIndex 5

# Supported PowerShell lifecycle releases
Get-EolInfo -ProductName powershell -ActiveSupport

# AKS versions available in a region
Get-AksVersion -Location uksouth

# Query one or all common DNS record types
Get-DnsResult -Domain example.com -RecordType MX
Get-DnsResult -Domain example.com -All

# Inspect a remote certificate and its chain
Get-TlsCertificate -HostName example.com -ShowChain
```

Use `Get-Help <command> -Full` for complete parameters and examples.

### Azure images and VM sizes

Live queries require Azure CLI on `PATH` and a signed-in account (`az login`) with
permission to read the Compute catalogue. They use the active CLI subscription;
pass `-Subscription <name-or-id>` to query another without changing your defaults.
Image searches with `-Catalog` are offline and need neither Azure CLI nor authentication.
Neither module creates resources, accepts Marketplace terms, or queries quota usage.
Compute pricing is optional through `-IncludePrice`; ordinary lookups make no pricing requests.
Both modules' region completion uses the full physical-region list reported
by Azure (63 names in the initial seed), refreshed by the catalogue workflow.
This can include restricted or preview regions, not a guarantee of subscription
access or VM/image availability. Arbitrary region names are still accepted.

```powershell
Set-PwshProfile -EnableAzureImages
Set-PwshProfile -EnableAzureCompute

# Find Windows Server 2025 variants in your target region
Get-AzureVmImage -Location uksouth -OS WindowsServer -Search 2025

# Only Windows client editions still within their normal security-support period
Get-AzureVmImage -Location westeurope -OS WindowsClient

# Explicitly include end-of-life and unclassified releases
Get-AzureVmImage -Location westeurope -OS WindowsClient -IncludeUnsupported

# Discover standard Canonical Ubuntu images available in this region
Get-AzureVmImage -Location uksouth -OS Ubuntu
Get-AzureVmImage -Location uksouth -OS Ubuntu -Search 22.04
Get-AzureVmImage -Location uksouth -OS Ubuntu -Search 26.04

# Include Pro, CIS, hardened, FIPS and minimal variants
Get-AzureVmImage -Location uksouth -OS Ubuntu -Expanded
Get-AzureVmImage -Location uksouth -OS Ubuntu -Expanded -Search cis

# Filter Azure-reported architecture and Hyper-V generation
Get-AzureVmImage -Location uksouth -OS Ubuntu -Search 26.04 -Arch amd64 -Generation Gen2
Get-AzureVmImage -Location uksouth -OS Ubuntu -Arch arm -Generation Gen2

# Other OS families, with tab completion for -OS
Get-AzureVmImage -Location uksouth -OS Debian
Get-AzureVmImage -Location uksouth -OS RHEL

# Browse any publisher, including those outside the configured OS presets
Get-AzureVmImage -Location uksouth -Publisher SUSE -Offer '*sles*'

# Fast offline search of the bundled snapshot
Get-AzureVmImage -Catalog -Search 26.04
Get-AzureVmImage -Catalog -OS Debian -Location eastus

# Custom offer, with wildcard SKU filtering
Get-AzureVmImage -Location uksouth -Publisher MicrosoftWindowsServer `
  -Offer WindowsServer -Sku '*2025*'

# Choose an exact SKU from the results, then format its image reference
$sku = Read-Host 'Image SKU'
Get-AzureVmImage -Location uksouth -Sku $sku | ConvertTo-AzureVmImageBicep

# List concrete versions for pinning (requires an exact SKU, no wildcards)
Get-AzureVmImage -Location uksouth -Sku $sku -ListVersions

# Find sizes with 4-8 enabled vCPUs and 16-32 GB memory
Get-AzureVmSize -Location uksouth -MinVCpus 4 -MaxVCpus 8 `
  -MinMemoryGB 16 -MaxMemoryGB 32 -Architecture x64

# Inspect all capabilities and subscription restrictions for one size
Get-AzureVmSize -Location uksouth -Name Standard_D4s_v5 | Format-List *

# Compare public PAYG estimates, including Windows licensing, in GBP
Get-AzureVmSize -Location uksouth -Name 'Standard_D*s_v5' `
  -IncludePrice -PriceOS Windows -Currency GBP
```

Live `Get-AzureVmImage` queries default to Windows Server. `-Search` is a case-insensitive
literal substring of the offer or SKU, treating dots and underscores as equivalent
(for example, `22.04` matches `22_04`). `-Sku` accepts PowerShell wildcards.
The Ubuntu preset discovers Canonical offers dynamically, including older and
newer releases. By default, offer/SKU names containing CIS, hardened, FIPS or minimal
tokens are excluded, as are Canonical's Ubuntu Pro variants. `-Expanded` includes
them again, for live and offline queries, including explicit publisher/offer
requests. Windows Pro editions remain visible. This name-based convenience filter
is not an authoritative licensing or security classification.
It queries SKUs for each matching offer, so a broad lookup can take longer than an
explicit `-Publisher Canonical -Offer <offer-from-results>` query.

**Supported releases only:** live and offline searches exclude end-of-life,
unreleased/preview and unclassified images by default. Support means the OS cycle's
normal security-maintenance period, including normal Windows Server extended
support but excluding paid ESU/ESM/EUS/LTSS extensions. Windows client editions and
LTSC releases have separate deadlines: a supported Windows 10 LTSC image can remain
visible even though ordinary Windows 10 is end-of-life.

`-OS WindowsClient` includes Azure Virtual Desktop images (`avd` and legacy `evd`
SKUs), plus Microsoft 365 Apps images from the `office-365` offer. These use Windows
Enterprise OS support dates; the filter does not verify the bundled apps' support
or licensing. Use `-OS WindowsClient -Search avd` for current AVD-named images,
or `-Search evd` for legacy names. No `-Expanded` switch is needed.

Dates come from [endoflife.date](https://endoflife.date/). Live searches fetch public
lifecycle data over HTTPS and cache successful responses for one hour per product;
they do not require the separate EndOfLife module. An unavailable or malformed
lifecycle response stops the supported-only query rather than returning unverified
results. `-IncludeUnsupported` bypasses lifecycle checks and that HTTP dependency.
It does not bypass variant filtering: combine `-Expanded -IncludeUnsupported`
when both specialised and older images are wanted.

Image names are mapped conservatively to known lifecycle products and cycles.
Unrecognized publishers, releases or naming patterns are hidden by default,
including Azure Linux until a verified lifecycle mapping is available. The filter
checks release-family support, not whether an individual image build is fully
patched or whether an update to a newer point release is required. Check the
vendor's lifecycle and your support entitlement before deployment.

SUSE includes the SLES 16 offer naming scheme. Rocky Linux includes CIQ community
images as well as RESF images. Flatcar's production `stable` channel is verified
through its [official release feed](https://www.flatcar.org/releases/), not an
invented fixed EOL date. Alpha, beta and unverified LTS channels remain opt-in.
Azure Linux 3.0 still requires `-IncludeUnsupported` because an OS-wide lifecycle
mapping has not been verified; this does not mean Microsoft has declared it EOL.
Azure Linux 4.0 is [currently preview](https://learn.microsoft.com/azure/azure-linux/release-cadence-lifecycle)
and is deliberately excluded by default.

`-Arch` accepts `amd64`/`x64` and `arm64`/`arm`. `-Generation` accepts `Gen1` or
`Gen2`; ARM is an architecture, not a generation. These filters use Azure image
metadata, not SKU-name guesses. Architecture and generation are included by default,
without an extra switch. Live queries fetch details for each candidate, so narrow
the offer/SKU/search when possible. For a faster name-only lookup, explicitly use
`-IncludeMetadata:$false`; this leaves both fields `Unknown`. Architecture or
generation filters always fetch metadata, even with that opt-out. Unknown values
never match platform filters, and a Gen1 image will not match `-Generation Gen2`.
The refreshed offline catalogue retains both fields without extra Azure calls.
Azure can list SKUs whose `latest` version no longer resolves. Metadata queries
warn and skip those specific entries, continuing to the remaining images.
Authentication, permission, malformed-response and other lookup errors still stop
the query; failures resolving explicitly listed versions are not skipped.

The default image table groups publisher, offer, region and source above each table,
with fixed Arch, Gen and Version columns followed by SKU stretching to the right
edge of the terminal. Short early results do not shrink the SKU column. Names wrap
only when they exceed the available width, rather than being truncated. Output remains objects: use
`Format-List *` for all properties or pipe selected results to Bicep conversion.

Ordinary lookups return one object per offer/SKU with the **unresolved `latest`
alias**, not a pinned version. `-ListVersions` makes a live version query and
sorts newest first within each offer. Use an explicit publisher and offer to pin
versions of one Ubuntu image: names such as `server` are shared across releases.
Pass a selected version object to `ConvertTo-AzureVmImageBicep` to preserve that
version. The generated `imageReference` belongs under a VM's `storageProfile`;
purchase plans, terms acceptance and VM/image compatibility are not validated.
Choose the required Core/Desktop Experience, generation and architecture variant
explicitly. Live custom queries use `-Publisher` instead of `-OS`; omit `-Offer`
to browse all of that publisher's offers, or supply an exact name or wildcard.

Presets cover Windows Server/client, Ubuntu, Debian, RHEL, SUSE, Oracle Linux,
Rocky Linux, AlmaLinux, Flatcar, Azure Linux and FreeBSD. Publisher mappings and offer
patterns live in [AzureImagesCatalog.json](AzureImagesCatalog.json). `-OS All`
queries every configured preset live and can be slow; it is not every Marketplace
appliance or reseller image. Generic publisher queries remain available for those.

`-Catalog` defaults to supported releases across all OS families and searches the bundled public-Azure
snapshot, including OS and publisher names. Its results are labelled
`Source = Catalog`; normal queries return `Source = Live`. A catalogue match is
not a live regional availability check. The bundled snapshot has been populated
from authenticated Azure discovery for `uksouth` and `eastus`, including metadata.
It is not an all-region offline index; use live queries for other regions.
Offline support checks use bundled `Lifecycles` dates, evaluated on every query so
an installed snapshot stops showing a release after its support deadline. Older
snapshots without lifecycle records require a refresh or `-IncludeUnsupported`.

The [Azure image update workflow](.github/workflows/update-azure-images.yml) runs
weekly or manually, validates results, and opens an independent module update PR.
New physical regions update both modules' completion and prepare independent
patch releases even without image changes. Image-only or lifecycle-only changes
do not bump the Compute module.
Lifecycle-date changes also trigger an update PR.
`AvailableLocations` is the full reported completion list; `Locations` remains the
configured subset used for image snapshots, initially `uksouth` and `eastus`.
See [catalogue automation setup](docs/release-automation.md#azure-image-catalogue)
for OIDC prerequisites, configured regions, local refreshes and first-run steps.

`Get-AzureVmSize` includes restricted sizes so they do not silently disappear.
Its `Restriction` summary distinguishes region-wide and zone-specific limits;
`Restrictions` retains the raw details for the requested region. `Zones` lists
advertised zones, not a promise of availability in each zone. `None` means no
reported SKU restrictions, **not guaranteed capacity or sufficient quota**.
CPU filters use enabled vCPUs (`vCPUsAvailable` for constrained-core sizes);
`TotalVCpus` preserves the underlying `vCPUs` capability. Missing CPU/memory
values stay null and are excluded by numeric filters; missing architecture is
shown as `Unknown`.

**Optional PAYG estimates:** `-IncludePrice` adds public retail prices from the
[Azure Retail Prices API](https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices).
It defaults to base Linux compute in USD. Use `-PriceOS Windows` for Windows
license-included rates and `-Currency GBP` (or another supported three-letter
currency) for reference estimates. `-PriceOS` selects the price basis only; it
does not check whether a VM size supports a particular OS or image. Both price
options require `-IncludePrice`.

Results default to a wrapped table, including single-size lookups. Pricing tables
group region, OS and currency above the rows and display `PAYG/hour` and `Est/730h`.
Use `Format-List *` to inspect all properties instead. Numeric `RetailHourly` and
`RetailMonthly` properties remain available for sorting and calculations;
monthly estimates assume 730 running hours and are rounded to two decimals.
`PriceStatus`, `PriceEffectiveDate`, `PriceRetrievedAt` and `PriceSource` expose
the match status and provenance. Missing or conflicting rates have status
`Unknown`, null numeric amounts and an explicit `Unknown` display, not zero.
Restricted sizes remain visible regardless of price availability.

Only ordinary hourly PAYG base-compute meters are matched by exact region,
SKU and price OS. Spot, Low Priority, Dev/Test, reservations, savings plans and
software-specific rates are excluded. These estimates are **not a total bill**:
disks, networking, Marketplace software, paid Linux distribution subscriptions,
taxes, negotiated discounts and Azure Hybrid Benefit are not calculated.
Non-USD rates are indicative, not a contractual billing conversion.

The public pricing API needs no additional authentication and covers commercial
Azure, not sovereign clouds. Complete regional responses are cached in memory
for one hour per region/currency and reused across SKU and OS selections.
Expired entries are refreshed; failed or incomplete requests are not cached.
Pricing failures warn and preserve VM size results with unknown prices. No pricing
request is made unless `-IncludePrice` is used and at least one size matches.

For testing directly from a checkout before installing the updated profile:

```powershell
Import-Module ./src/modules/PwshProfile.AzureImages/PwshProfile.AzureImages.psd1
Import-Module ./src/modules/PwshProfile.AzureCompute/PwshProfile.AzureCompute.psd1
```

Reference: [Azure CLI image discovery](https://learn.microsoft.com/en-us/cli/azure/vm/image)
and [VM resource SKUs](https://learn.microsoft.com/en-us/cli/azure/vm#az-vm-list-skus).

## Safe installation and updates

Every published bundle contains `PwshProfile.release.json`. Before replacing a
file, the installer:

1. validates release metadata and the requested Stable or Preview channel;
2. verifies every downloaded asset against its SHA-256 hash;
3. parses PowerShell scripts, module manifests, format views, theme JSON, and
   the embedded SemVer version;
4. checks previously installed files against the local baseline; and
5. stages replacements, retains timestamped backups, and rolls back the entire
   transaction if installation or the final baseline write fails.

Optional modules may also receive independent releases. Those updates use the
same manifest verification, drift detection, staging, and rollback protections
without changing the profile version or unrelated modules.

## Local development

Clone the repository and install directly from the working tree:

```powershell
git clone https://github.com/smoonlee/oh-my-posh-profile.git
Set-Location oh-my-posh-profile
.\src\Invoke-PwshProfileSetup.ps1 -LocalSource
```

`-LocalSource` trusts the checked-out files and bypasses GitHub Release metadata.
It still performs syntax, JSON, manifest, version, hash, staging, backup, and
rollback checks. Use it only for development.

To refresh only locally installed runtime files and their baseline:

```powershell
.\src\Invoke-PwshProfileSetup.ps1 -RunPhase ProfileUpdate -LocalSource
```

For a clean-machine development install, include the normal external setup
phases while sourcing project files locally:

```powershell
.\src\Invoke-PwshProfileSetup.ps1 `
  -RunPhase All `
  -NerdFont CaskaydiaCove `
  -LocalSource
```

## Validation

The Windows validation workflow checks workflow YAML, release packaging,
release discovery and pagination, update transactions, startup guards, responsive
prompt behaviour, Azure completion, bundle and module rollback, lifecycle release
automation, TLS/DNS fixes, PowerShell 5.1 compatibility, and a real theme render.

Run the PowerShell 7 regression scripts from `scripts/`, or use the same list in
[`.github/workflows/validate.yml`](.github/workflows/validate.yml).

## Releases and maintenance

- Release notes: [`CHANGELOG.md`](CHANGELOG.md)
- Release procedure: [`docs/create-release.md`](docs/create-release.md)
- Independent module releases: [`docs/release-automation.md`](docs/release-automation.md)
- Prompt layout notes: [`docs/prompt-layout.md`](docs/prompt-layout.md)

GitHub Actions refresh the Nerd Fonts and endoflife.date product catalogs and
open reviewable pull requests when upstream data changes. Actions are pinned to
immutable commit SHAs, with Dependabot tracking updates.

## Acknowledgements

- [Oh My Posh](https://ohmyposh.dev/)
- [Nerd Fonts](https://www.nerdfonts.com/)
- [Chris Titus Tech's PowerShell profile](https://github.com/ChrisTitusTech/powershell-profile)
- [Scott Hanselman: My Ultimate PowerShell Prompt](https://www.hanselman.com/blog/my-ultimate-powershell-prompt-with-oh-my-posh-and-the-windows-terminal)
- [endoflife.date](https://endoflife.date/)
