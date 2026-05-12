# native_fmt.ps1 — Nucleor source formatter entry point.
#
# Formatter placeholder. For now this prints a diagnostic and exits
# non-zero so CI gates flag the missing tool instead of silently passing.

[CmdletBinding()]
param(
    [string]$FilePath = "",
    [switch]$Check,
    [switch]$Write
)

$ErrorActionPreference = 'Stop'

Write-Host "nuc fmt: formatter not yet implemented." -ForegroundColor Yellow
Write-Host ""
Write-Host "  The Nucleor source formatter has not yet shipped."
Write-Host "  Planned shape: gofmt-style canonical rewrite (no opinion knobs)."
Write-Host ""
if ($FilePath) {
    Write-Host "  Requested: $FilePath"
}
if ($Check) {
    Write-Host "  Mode: --check (would have validated formatting)"
}
if ($Write) {
    Write-Host "  Mode: --write (would have rewritten in place)"
}
Write-Host ""
Write-Host "  Workaround today: Nucleor source style is dictated by"
Write-Host "  convention (see docs/getting-started.md). Format manually"
Write-Host "  until the formatter ships."

exit 2
