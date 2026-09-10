# Copilot prompt layout

The Copilot segment in `src/themes/quick-term-cloud.omp.json` selects the full
gauge, percentage only, or an empty segment according to the remaining space
on the first prompt row. It subtracts the rendered OS, elevation, path, Git,
and execution-time text from `POSH_TERMINAL_WIDTH`. The profile refreshes that
environment variable before each prompt.

The width update is installed in Oh My Posh's module-scoped `Set-PoshContext`
hook, after Oh My Posh captures command status. The profile preserves any
existing context callback and avoids wrapping `prompt`, including on reload.

Cloud context segments use `cache.duration: none`, so every render reads their
current source data instead of reusing the previous 30–60-second segment cache.
This may increase render time on slow machines. Azure PowerShell context still
depends on the context supplied to Oh My Posh; disabling a segment cache does not
refresh an externally maintained environment variable. Copilot uses a separate
one-minute quota cache to reduce network requests during prompt redraws. Usage
figures may lag by up to a minute; the layout still recalculates on each render.
A cold or expired cache can still incur the configured three-second HTTP timeout.

`copilotLayoutReserve` reserves 25 columns for the clock, powerline separators,
and a spacing cushion. Colour markup is removed before counting Unicode
characters. This assumes single-cell Nerd Font glyphs; unusually wide Unicode
folder or branch names may require a larger reserve.

Aliases used by the calculation are case-sensitive. Keep `Path` and `Git`
consistent with their references in the Copilot template.

The right block can still move to another row if the path, Git status, timer,
and clock cannot fit even with Copilot hidden. Existing terminal scrollback
does not get re-rendered when the window is resized.

With PSReadLine loaded, the profile checks the width on `PowerShell.OnIdle`
(normally after roughly 300 ms without input). When the width changes and the
editing buffer is empty, it redraws the active prompt automatically. Rendering
time is additional, so this is a near-real-time update, not a continuous animation.
Partially typed commands are left alone; the normal next-prompt refresh remains
available. Hosts without PSReadLine or working console APIs use that fallback.
Reloading the profile replaces its resize subscription without removing other
idle handlers.

Run the isolated handler and subscription checks in a fresh process with
`pwsh -NoProfile -File scripts/Test-PoshResize.ps1`. To verify the visual result,
install the updated profile and theme, open a new PowerShell session, and resize
the window with an empty command line. Also check that resizing with a partially
typed command leaves the input intact. These visual checks require an interactive
terminal; the automated checks use a simulated console and line editor.
