# bin/

Committed bootstrap and support binaries.

## Tracked Artifacts

| File | Purpose |
|---|---|
| `nucleor.exe` | Windows x86_64 bootstrap compiler. This is the primary first-use artifact on Windows. |
| `nucleor-lsp.exe` | Windows LSP support binary. |
| `nucleor.exe.bootstrap` | Windows recovery snapshot used when rebuilding or repairing the primary bootstrap binary. |

Linux and macOS native binaries are not committed. Linux users run
`tools/bootstrap_linux.sh`, which compiles `bootstrap/nucleor_s1_seed.ll` and
`stdlib/runtime/nucleor_llvm_rt.c` into `bin/nucleor`.

## Local Generated Files

These are intentionally ignored:

- `bin/nucleor`
- `bin/nucleor_tools`
- `bin/nucleor_tools.exe`
- `bin/nucleor_v*.exe`

They are reproducible development outputs and should not be committed.

## Version Check

```powershell
.\bin\nucleor.exe --version
```

Expected v1.1.0 output:

```text
nucleor 1.1.0 (self-hosted, llvm backend)
```
