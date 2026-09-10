# Module review

Reviewed all six modules. The six findings below are now addressed in the working
tree. DNS is version `1.0.1`, TLS is version `1.0.2`, and the rollback fix is in
the profile installer/updater.

## Fixes and regression checks

- Certificate creation and PFX splitting require `-Force` to replace existing
  files. Outputs are staged, and failed extraction preserves the old files.
- A managed deadline closes stalled TLS connections while allowing successful
  handshakes and certificate-chain capture on the PowerShell thread.
- `-ShowChain` returns a reusable result object. Local, remote, and chain
  fingerprints now use SHA-256.
- Unsupported native DNS types fall back to dig, preserving `-Server`. Windows
  CAA queries require dig on PATH; missing dependencies and failed `-All`
  queries now produce explicit diagnostics. No public resolver is substituted.
- Failed module writes and failed imports restore replaced files, remove newly
  added artifacts, and reload the previously loaded module. Incomplete rollback
  reports its errors and retains backups.

Run in fresh PowerShell 7 processes (OpenSSL required for certificate tests):

```powershell
pwsh -NoProfile -File scripts/Test-ModuleFixes.ps1
pwsh -NoProfile -File scripts/Test-ModuleRollback.ps1
pwsh -NoProfile -File scripts/Test-EndOfLifeRelease.ps1
```

All passed on PowerShell 7.6.5. Tests cover real loopback TLS success and timeout,
OpenSSL/PFX file operations, overwrite guards, matching fingerprints, mocked DNS
routing/errors, and injected update write/import failures. PowerShell 5.1 and
live external DNS/API behaviour remain unverified.

## Original audit findings (before fixes)

### Confirmed by execution

1. **High: TLS handshake is unbounded.** In
   `PwshProfile.TlsCertificate.psm1:124`, synchronous `AuthenticateAsClient` has
   no timeout. `TimeoutSec` only bounds TCP connection. A loopback server that
   accepts TCP but never responds to TLS remained blocked for four seconds
   after connection with `-TimeoutSec 1`. The test process was then stopped.
   Apply a deadline to the handshake as well as connection establishment.
2. **Medium: TLS chain mode breaks its documented pipeline example.**
   `Get-TlsCertificate -ShowChain` formats to the host and returns before emitting
   the result. With a synthetic endpoint result containing a chain, the output
   object count was zero. `(Get-TlsCertificate ... -ShowChain).Chain` therefore
   cannot work as documented. Return the object and move presentation to format
   data or a separate display option.
3. **Medium: CAA DNS queries fail on Windows.** `Get-DnsResult` accepts `CAA`,
   but passes it to `Resolve-DnsName`, whose installed `RecordType` enum lacks
   CAA. The failure was reproduced at parameter binding without a network query.
   `-All` catches this failure and silently omits CAA. Route unsupported record
   types through a capable resolver and distinguish failed queries from no data.

### Additional findings

4. **High: certificate output lacks overwrite protection.**
   `Split-PfxCertificate` and `New-SelfSignedTlsCertificate` derive fixed output
   names and pass them directly to OpenSSL without checking for existing files
   or offering `-Force`. Repeating a command can replace a certificate/private
   key. Check all destinations before writing and stage outputs so a later
   failure does not leave a partially replaced set. Reproduced with disposable
   test certificates: a second `New-SelfSignedTlsCertificate` call changed the
   private-key file hash without `-Force`. No user certificate files were touched.
5. **Medium: inconsistent certificate fingerprints.** Remote lookup uses
   `X509Certificate2.Thumbprint`, while file lookup explicitly asks OpenSSL for
   SHA-256. They populate the same `Thumbprint` property with different digest
   algorithms. Standardize the algorithm or expose clearly named properties.
6. **High: independent-module rollback is incomplete.** Code inspection of
   `Invoke-PwshProfileSetup.ps1:3020–3045` shows that rollback only copies files
   with backups. A new artifact has no backup and is left installed if a later
   file fails. The module is removed from the session before installation, but
   re-import happens only on success, so a failed update also leaves a previously
   loaded module unavailable. Track newly created files for removal and restore
   the previous module's loaded state. This was not fault-injected into an actual
   installation.

### Audit coverage and limitations

- All six manifests validate, modules import on PowerShell 7.6.5, and exported
  functions match the manifests.
- NetworkCidr passed /0 through /32 boundary checks and the final /32 subnet
  index of a /0. This does not validate every cloud-provider policy.
- EOL's local product listing returned 472 entries; AKS's local region listing
  returned 36 entries. These do not validate remote API behaviour.
- The audit originally found no dedicated module behaviour tests. The regression
  scripts above now cover these fixes; broader API-response tests remain useful.
- The manifests advertise PowerShell 5.1, but this review ran executable checks
  successfully only on 7.6.5. A Windows PowerShell 5.1 process produced no output
  before the 45-second test deadline. This is an environment/test limitation,
  not evidence that a module failed. Add a working Windows PowerShell 5.1 test job.
- OpenSSL 4 tests passed for self-signed certificate creation, key matching,
  password-protected PFX export, encrypted-key extraction, and passwordless PFX
  splitting. Synthetic files were removed after testing.
- Authenticated AKS calls, PublicIP/EOL HTTP requests, and successful remote
  certificate-chain retrieval were not exercised.

The original repair priorities are covered by the fixes listed at the top.
