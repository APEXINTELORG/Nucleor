# native_lsp.ps1 — Nucleor language-server entry point.
#
# v0.8.55 PKG-2 fix: restored as a stub so `nuc lsp` no longer
# crashes the router with "Cannot find path". Phase 2b will land
# the actual LSP server; for now this prints the diagnostic and
# exits with a non-zero code so editors flag the missing server
# instead of silently leaving an unresponsive socket.
#
# Reference: docs/rfcs/gap-analyses/Nucleor_Module_Packaging_Gap_
# Analysis_and_RFC_2026-05-04.md PKG-2.

[CmdletBinding()]
param(
    [string]$Root = "",
    [string]$CompilerPath = ""
)

$ErrorActionPreference = 'Stop'

Write-Host "nuc lsp: language server not yet implemented (PKG-2 stub v0.8.55)." -ForegroundColor Yellow
Write-Host ""
Write-Host "  The Nucleor LSP server is on the v1.0 punchlist but has"
Write-Host "  not yet shipped. Phase 2b plan: stdio-based JSON-RPC LSP"
Write-Host "  with diagnostics, hover, go-to-definition, completion."
Write-Host ""
if ($Root) {
    Write-Host "  Root: $Root"
}
if ($CompilerPath) {
    Write-Host "  Compiler: $CompilerPath"
}
Write-Host ""
Write-Host "  Reference: docs/rfcs/gap-analyses/Nucleor_Module_Packaging_Gap_Analysis_and_RFC_2026-05-04.md PKG-2."
Write-Host ""
Write-Host "  Workaround today: editors using LSP for Nucleor will see"
Write-Host "  no language-server diagnostics. Use `nuc build` or"
Write-Host "  `nuc check` from the command line for compile-time"
Write-Host "  feedback until the LSP ships."

exit 2
