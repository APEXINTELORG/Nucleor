# native_fmt.ps1 — Nucleor source formatter entry point.
#
# v0.8.55 PKG-2 fix: restored as a stub so `nuc fmt` no longer
# crashes the router with "Cannot find path". Phase 2b will land
# the actual formatter; for now this prints the diagnostic and
# exits with a non-zero code so CI gates flag the missing tool
# instead of silently passing.
#
# Reference: docs/rfcs/gap-analyses/Nucleor_Module_Packaging_Gap_
# Analysis_and_RFC_2026-05-04.md PKG-2.

[CmdletBinding()]
param(
    [string]$FilePath = "",
    [switch]$Check,
    [switch]$Write
)

$ErrorActionPreference = 'Stop'

Write-Host "nuc fmt: formatter not yet implemented (PKG-2 stub v0.8.55)." -ForegroundColor Yellow
Write-Host ""
Write-Host "  The Nucleor source formatter is on the v1.0 punchlist but"
Write-Host "  has not yet shipped. Phase 2b plan: gofmt-style canonical"
Write-Host "  rewrite (no opinion knobs)."
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
Write-Host "  Reference: docs/rfcs/gap-analyses/Nucleor_Module_Packaging_Gap_Analysis_and_RFC_2026-05-04.md PKG-2."
Write-Host ""
Write-Host "  Workaround today: Nucleor source style is dictated by"
Write-Host "  convention (see docs/getting-started.md). Format manually"
Write-Host "  until the formatter ships."

exit 2
