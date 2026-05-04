# SPEC — Nucleor LSP Server

**Status:** Draft (drift recovery — application, not language)
**Date:** 2026-05-03
**Predecessor:** V2 had `crates/nucleor-lsp`; OSS dropped it.

## Architecture choice

Two paths. Going with **(A) subprocess-first** for v0 and library-factor in v1.

### (A) Subprocess (chosen for v0)
- `nucleor-lsp.exe` is a standalone JSON-RPC daemon (LSP 3.17+ protocol).
- Per request, spawns `nucleor.exe --lsp-mode --emit-diagnostics-json <file>` and parses the JSON output.
- Pros: no compiler refactor; can ship in 1-2 weeks.
- Cons: subprocess overhead per keystroke; ~50–200ms latency.

### (B) Library (deferred to v1)
- Refactor `compiler/nucleor_s1_compiler.nr` parser + type-checker into a `nucleor-frontend` library.
- LSP imports the library, holds parsed AST in memory, incremental re-parse on edit.
- Pros: <10ms latency; live diagnostics on every keystroke.
- Cons: substantial compiler refactor; risks self-host stability.

## v0 LSP capabilities

- **textDocument/didOpen, didChange, didClose** — track open files.
- **textDocument/diagnostics (push)** — re-parse on save; emit NR020/TYP-005/TYP-008/etc as LSP diagnostics with severity + range + workaround pointer.
- **textDocument/hover** — show fn signature + return type for the symbol under cursor (parsed from the latest `nuc summary` output).
- **textDocument/definition** — go-to-definition via `nuc summary --emit-symbol-table`.
- **textDocument/completion** — basic ident completion from in-scope symbols. (Stdlib rod completions deferred to v1.)
- **textDocument/formatting** — invoke `nuc fmt` (existing tool).
- **textDocument/codeAction** — surface workaround pointers from defensive halts as quick-fixes (e.g. `x++` halt offers `x = x + 1` quick-fix).

## v1 LSP capabilities (library path)

- Live diagnostics on every keystroke (<10ms).
- Workspace-wide rename via call-graph walk.
- Inline parameter hints.
- Type-on-hover for any expression (not just symbols).
- Live `@law` verification status in the gutter.

## Compiler-side support needed

Add `--lsp-mode` flag to `nucleor.exe`:
- Suppresses normal stderr output.
- Emits diagnostics + symbol table as line-delimited JSON to stdout.
- Exits zero on parse-fail (still emits diagnostics; LSP needs to know about them).
- Adds `--emit-symbol-table=json` for hover + go-to-def.

## Cost

v0 subprocess LSP: ~600 LOC in `tools/nucleor-lsp/main.rs` (or `.nr` if we self-host the LSP) + ~200 LOC compiler-side (`--lsp-mode`, JSON emit). 1 week.

v1 library LSP: ~3000 LOC compiler refactor (extract frontend) + ~500 LOC LSP integration. 1 month.

## Editor support (parallel)

- **VS Code:** thin TS extension that spawns `nucleor-lsp` and forwards LSP messages. ~200 LOC TS.
- **Neovim:** `nucleor.lua` config snippet that points `nvim-lspconfig` at `nucleor-lsp`. ~50 LOC.
- **Helix:** `languages.toml` entry. ~15 LOC.
- **Emacs:** `lsp-mode` config. ~30 LOC.

## Closure criteria

- `nucleor-lsp` daemon starts on stdin/stdout.
- VS Code shows red squiggles for NR020 / TYP-005 / TYP-008 errors.
- Hover on a fn name shows signature + return type.
- Go-to-definition works for in-file symbols.
- Workaround-pointer quick-fixes appear for the 19+ defensive-halt cases.
