# Bootstrap Seed Provenance

`bootstrap/nucleor_s1_seed.ll` is the canonical LLVM IR that anyone
with `clang` 18+ can use to produce a working `bin/nucleor`. It is
the compiler's own emitted IR; the bootstrap is self-hosted.

## Current seed

```
sha256: 55a2bce65aec70a51b5dee8b714f2aa3d31fdc0ef9b3c575530f9e197ff8da7c
size:   13 MB (varies slightly with source)
```

## Provenance

The seed is **emitted on Linux** by the bootstrap pipeline
documented in `tools/bootstrap_linux.sh`. The mechanism:

1. Stage-1: `clang -O2 bootstrap/nucleor_s1_seed.ll
   stdlib/runtime/nucleor_llvm_rt.c -o bin/nucleor` — links the
   committed seed against the runtime C to produce a working
   compiler.
2. Stage-2: that compiler builds `compiler/nucleor_s1_compiler.nr`
   into `target/nucleor_s2.ll`.
3. **Fixed-point check**: `target/nucleor_s2.ll` is compared
   byte-for-byte against `bootstrap/nucleor_s1_seed.ll`. They
   MUST be identical — that's the self-host invariant.
4. Stage-2 link: the stage-2 IR replaces the seed-built `bin/nucleor`.

When the source changes (any commit that affects compiler output),
the seed must be regenerated:

```bash
NUCLEOR_LLVM_OPT=-O2 ./bin/nucleor build compiler/nucleor_s1_compiler.nr -o target/_seed --no-cache
cp target/_seed.ll bootstrap/nucleor_s1_seed.ll
bash tools/bootstrap_linux.sh  # verifies fixed point
```

## Verification gates

Two `verify.sh` steps validate the seed every CI run:

- **T1.7 `bootstrap seed matches current compiler`** — runs the
  fixed-point check explicitly. Fails if the committed seed
  doesn't reproduce from the current source.
- **T1.8 `self-host compiler IR fixed point`** — re-runs the
  bootstrap end-to-end and confirms stage-1 → stage-2 produces
  byte-identical IR.

Both gates are in the `regression` bucket of the verifier
breakdown.

## Cross-platform consistency

The seed IR is platform-neutral: it's pure LLVM IR with no
target-specific assumptions beyond x86-64 (the only architecture
Nucleor currently emits for). Linking with Linux clang, Windows
clang, or macOS clang produces a working compiler on each platform
respectively. The IR itself is identical.

The Windows release line consumes the same `bootstrap/nucleor_s1_seed.ll`
as the Linux line; the Windows-specific bootstrap script
(`tools/bootstrap_windows.ps1`, when present) links it against the
same runtime sources.

## What "Linux-emitted" means here

For the v1.1.0 release line, the committed seed was historically
generated on the Windows release workstation. v1.1.1 (this branch
line) regenerates the seed on hosted Linux x86_64 (Ubuntu 24.04,
LLVM 18) as part of the closure-capture / sanitize / benchmark
work; T1.7 verifies the regeneration is reproducible.

The seed is **deterministic** in two senses:
1. **Per-platform**: same source + same compiler binary +
   same LLVM version produces byte-identical IR.
2. **Cross-platform** (verified): Linux- and Windows-emitted seeds
   from the same source produce byte-identical IR. The CI gate
   does not yet enforce cross-platform equivalence automatically;
   this is a manual sanity step for release tags.
