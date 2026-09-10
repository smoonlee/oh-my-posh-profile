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
| DNS | `Set-PwshProfile -EnableDns` | `Get-DnsResult` |
| TLS certificates | `Set-PwshProfile -EnableTlsCertificate` | `Get-TlsCertificate`, `Split-PfxCertificate`, `New-PfxCertificate`, `Test-CertificateKeyMatch`, `New-SelfSignedTlsCertificate` |

Disable a module by passing `$false` to its switch:

```powershell
Set-PwshProfile -EnableDns:$false
```

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
