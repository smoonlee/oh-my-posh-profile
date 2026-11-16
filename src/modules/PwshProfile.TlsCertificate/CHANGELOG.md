# PwshProfile.TlsCertificate changelog

## [1.0.3] - 2026-11-11

- Stage PFX creation and preserve an existing destination when OpenSSL fails,
  including forced replacements.
- Pass passwords to OpenSSL as UTF-8 on PowerShell 7 and Windows PowerShell 5.1,
  without changing the caller's encoding or exposing passwords in arguments.
- Capture normal OpenSSL stderr output and use the native exit code so progress
  output does not terminate certificate operations on Windows PowerShell 5.1.

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
