# PwshProfile.TlsCertificate changelog

## [1.0.2] - 2026-09-08

- `-ShowChain` now prints the certificate chain table automatically instead of
  only populating the returned object's `Chain` property.

## [1.0.1] - 2026-09-08

- Bound the TLS handshake as well as TCP connection establishment.
- Return certificate objects with `-ShowChain`, including their `Chain` property.
- Use SHA-256 for remote, local, and chain fingerprints.
- Require `-Force` before self-signed creation or PFX splitting replaces existing
  outputs; stage all outputs and restore previous files if installation fails.

## [1.0.0] - 2026-09-01

- Initial release with TLS inspection, PFX conversion, key matching, and
  self-signed certificate helpers.
