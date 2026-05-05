# Editor integrations for Nucleor LSP

Adopter-installable LSP configs for the four editors the spec
calls out (VS Code, Neovim, Helix, Emacs). All four spawn
`nucleor-lsp.exe` via stdio and forward LSP messages.

| Editor | Path | Setup |
|---|---|---|
| VS Code | `vscode/` | `cd vscode && npm install && npm run compile`; install via "Extensions: Install from VSIX" or `code --install-extension`. |
| Neovim | `neovim/nucleor-lsp.lua` | `:luafile editors/neovim/nucleor-lsp.lua` (requires `nvim-lspconfig` plugin). |
| Helix | `helix/languages.toml` | append to `~/.config/helix/languages.toml`. |
| Emacs | `emacs/nucleor-lsp.el` | `(load "editors/emacs/nucleor-lsp.el")` (requires `lsp-mode` package). |

## Prerequisites

`nucleor-lsp.exe` must be on PATH (or configured per editor's
override mechanism). Build it from the OSS repo:

```
nucleor.exe build compiler/nucleor_lsp.nr
mv target/nucleor_lsp.exe bin/nucleor-lsp.exe
```

The Nucleor compiler (`bin/nucleor.exe`) must also be on PATH
or in the same directory as `nucleor-lsp.exe`. The daemon
spawns `bin\nucleor.exe build <file>` per change to capture
diagnostics.

## What you get (v0)

- Real-time push diagnostics on every file open + save.
- Severity-aware: `error[*]` shows red, `warning[*]` yellow,
  `info[*]` blue.
- Range-aware: warnings with `--> @line LINE:COL` annotations
  land at the offending token; others fall back to the file
  header.
- Standard LSP base protocol (Content-Length-framed JSON-RPC
  2.0).

## What's deferred (v1, library-mode LSP)

- <10ms incremental diagnostics on every keystroke (today: ~50–200ms
  per save / didChange).
- Hover with type info.
- Go-to-definition.
- Workspace-wide rename.
- Inline parameter hints.

These all land when the compiler frontend is refactored into
a `nucleor-frontend` library (~3000 LOC). Tracked under V1.16
Phase v1 in `docs/rfcs/SPEC-LSP-server.md`.
