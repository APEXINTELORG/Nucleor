# bootstrap/ — Cross-platform compiler bootstrap seed

This directory holds a checked-in LLVM IR snapshot of the self-hosted
compiler so that fresh Linux / macOS hosts can build `bin/nucleor`
without already having a working `bin/nucleor` to start from.

## Files

| File | Origin | Purpose |
|---|---|---|
| `nucleor_s1_seed.ll` | Emitted on Windows by running `bin/nucleor.exe build compiler/nucleor_s1_compiler.nr -o nucleor_seed` and copying `target/nucleor_seed.ll` here. | Stage-0 IR. The `.ll` is intentionally target-agnostic (no `target triple`, no `target datalayout`), so clang on any host can lower it for the host's native triple. |

The seed is platform-portable because the runtime calling convention
(every value passed/returned as `i64` or `ptr`) and the IR emission path
do not bake in any host-specific layout. The Windows-only / POSIX-only
deltas live entirely inside the C runtime (`stdlib/runtime/nucleor_llvm_rt.c`)
which is compiled separately by the host clang.

## How Linux / macOS bootstrap works

1. Host clang compiles `bootstrap/nucleor_s1_seed.ll` together with
   `stdlib/runtime/nucleor_llvm_rt.c` → produces a working `bin/nucleor`
   ELF (Linux) or Mach-O (macOS). This is the **stage-1** binary.
2. The stage-1 binary recompiles its own source
   (`compiler/nucleor_s1_compiler.nr`) → emits a fresh `target/nucleor.ll`.
3. The fresh `.ll` is compared byte-for-byte against the seed (after
   normalizing for absolute paths in `#cfile` directives if any). They
   must match — this is the **fixed-point check**, the same invariant
   the Windows v0.2.x chain has held since v0.2.50.
4. The fresh `.ll` is linked again to produce the **stage-2** binary,
   which is what we ship.

The bootstrap script `tools/bootstrap_linux.sh` automates steps 1–4.

## When to refresh the seed

Refresh the seed (re-run the Windows emit + commit the new `.ll`)
whenever the compiler IR shape changes in a way that affects the
emitted IR for `compiler/nucleor_s1_compiler.nr`. In practice this
means:

- After any change to compiler emission helpers (`emit_*`, `lower_*`,
  `irmod`).
- After bumping the runtime ABI in `stdlib/runtime/nucleor_llvm_rt.c`
  if it adds new `declare`s the compiler now emits unconditionally.
- Before tagging a release.

To refresh:

```powershell
# On Windows, with bin\nucleor.exe in place:
.\nuc.bat build compiler\nucleor_s1_compiler.nr -o nucleor_seed
Copy-Item target\nucleor_seed.ll bootstrap\nucleor_s1_seed.ll
# Confirm the seed compiles back to a fixed point on Linux via CI.
git add bootstrap\nucleor_s1_seed.ll
```

## Why not check in the binaries directly?

A native binary is platform-specific, while the seed `.ll` is portable
(one file works for Linux x86_64, Linux aarch64, macOS arm64, etc.).
We avoid checking in pre-built ELF/Mach-O binaries because (a) they
inflate the repo, (b) they're opaque to code review, and (c) they
require a separate seed per architecture. The `.ll` seed solves all
three.
