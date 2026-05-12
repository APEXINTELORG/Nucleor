# native_lsp.ps1 — Nucleor language-server entry point.
#
# Language-server placeholder. For now this prints a diagnostic and exits
# non-zero so editors flag the missing server instead of silently leaving
# an unresponsive socket.

[CmdletBinding()]
param(
    [string]$Root = "",
    [string]$CompilerPath = ""
)

$ErrorActionPreference = 'Stop'

Write-Host "nuc lsp: language server not yet implemented." -ForegroundColor Yellow
Write-Host ""
Write-Host "  The Nucleor LSP server has not yet shipped."
Write-Host "  Planned shape: stdio-based JSON-RPC LSP"
Write-Host "  with diagnostics, hover, go-to-definition, completion."
Write-Host ""
if ($Root) {
    Write-Host "  Root: $Root"
}
if ($CompilerPath) {
    Write-Host "  Compiler: $CompilerPath"
}
Write-Host ""
Write-Host "  Workaround today: editors using LSP for Nucleor will see"
Write-Host "  no language-server diagnostics. Use `nuc build` or"
Write-Host "  `nuc check` from the command line for compile-time"
Write-Host "  feedback until the LSP ships."

exit 2
