# PwshProfile.AzureKubernetes changelog

## [1.0.1] - 2026-11-11

- Validate legacy and current Azure CLI response schemas and Kubernetes version
	fields instead of returning blank version rows for malformed responses.
- Preserve preview/default flags and return no rows for valid empty responses.

## [1.0.0] - 2026-08-26

- Initial release with `Get-AksVersion`.
