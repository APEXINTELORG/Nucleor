# Editor Integrations

This directory contains starter LSP configuration for VS Code, Neovim,
Helix, and Emacs. Each integration starts `nucleor-lsp.exe` over stdio and
lets the compiler report diagnostics for `.nr` files.

| Editor | Path | Setup |
|---|---|---|
| VS Code | `vscode/` | `cd editors/vscode && npm install && npm run compile`; install the packaged extension through VS Code. |
| Neovim | `neovim/nucleor-lsp.lua` | Load the Lua file from your Neovim config. Requires `nvim-lspconfig`. |
| Helix | `helix/languages.toml` | Append the table to `~/.config/helix/languages.toml`. |
| Emacs | `emacs/nucleor-lsp.el` | Load the file from Emacs. Requires `lsp-mode`. |

## Prerequisites

`nucleor-lsp.exe` must be on `PATH`, or configured explicitly in the editor
integration. Build it from the repository:

```powershell
.\nuc.bat build compiler\nucleor_lsp.nr -o nucleor-lsp
```

The compiler binary must also be available as `bin/nucleor.exe` on Windows or
`bin/nucleor` on POSIX hosts. The language server invokes the compiler to
produce diagnostics.

## Current Surface

- Diagnostics on file open and save.
- Severity-aware error, warning, and info reporting.
- Range-aware diagnostics when the compiler provides source locations.
- Standard `Content-Length` framed JSON-RPC transport.

Hover, rename, go-to-definition, and richer incremental analysis are planned
tooling work. The compiler remains the source of truth for diagnostics.
