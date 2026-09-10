# Profile UX review

Scope: the PowerShell profile, prompt theme, startup/update messages, and Azure
completion. This was a code and renderer review, not a visual inspection in a
live Windows Terminal session.

## Improvements made

- **Preserve command outcomes.** The width refresh previously ran before Oh My
  Posh could read `$?`, potentially hiding failed PowerShell commands. It now
  runs in the module's context hook, after status capture.
- **Make reload safe.** Oh My Posh can skip initialization when already loaded.
  Rewrapping `prompt` could therefore capture the wrapper itself and recurse.
  Context installation preserves the original callback once and leaves the
  prompt function intact. Resize event registration remains idempotent.
- **Clean up cloud context.** Fixed the corrupted tree glyph and matched alias
  casing to cross-segment references. The first active provider starts with
  `╰─`; subsequent providers get `||`. Previously empty conditionals always
  emitted separators, including when Azure or AWS was the only active provider.
- **Refresh cloud context on every render.** Disabled the theme's Kubernetes,
  Azure CLI, Azure PowerShell, and AWS segment caches. This removes the previous
  30–60-second theme cache delay after a context switch. Source tools and
  environment variables still determine what context is available.
- **Bound Azure completion waits.** Reduced the child-process deadline from five
  to two seconds, drained diagnostic output concurrently, and added process-tree
  termination and disposal. Failed or timed-out attempts return no candidates,
  rather than reading a partially written completion file. A cold Azure CLI may
  exceed the new deadline; prompt and completion latency still need measurement
  on the user's installed tools.

## Recommended follow-ups

Copilot's quota cache has also been increased from five seconds to one minute.
This reduces request frequency during resize redraws without changing the layout
calculation. Usage can lag by up to a minute, and an expired-cache request can
still take up to the configured three-second HTTP timeout.

| Priority | Friction | Suggested improvement | Tradeoff |
| --- | --- | --- | --- |
| Low | Startup can print separate update warnings for the profile and several modules. | Combine available updates into one concise notice with the update command. | Less version detail at startup; retain detail in the status command. |
| Low | Long context and subscription names can wrap the cloud row. | Explore a dedicated narrow-terminal layout that retains full identifying names on separate lines. | More vertical space; truncation could make similar environments hard to distinguish. |

## Validation

- PowerShell parser and isolated handler tests passed.
- Failed-command status, chained context callbacks, repeated installation,
  unchanged/invalid widths, typed input, and failed redraws were checked.
- Real event registration tests confirmed a single resize handler after reload
  and preservation of unrelated idle handlers.
- Oh My Posh v31.2.0 rendered all 16 cloud-provider combinations using synthetic
  data, with the expected leading glyph and separator count.
- `pwsh -NoProfile -File scripts/Test-AzureCompletion.ps1` checks large output on
  both pipes, failed exit codes, missing executables, bounded waits, and cleanup
  of a real synthetic parent/child process tree. It does not call Azure services.

Remaining manual checks: resize an empty and a partially typed prompt in Windows
Terminal; repeat with long branch/context names and a failed command. Start a
fresh session after installing this revision to replace the previous wrapper.
