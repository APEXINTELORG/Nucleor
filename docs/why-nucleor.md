# Why Nucleor

A one-pager for people deciding whether to spend an evening on this.

## The pitch in three sentences

Nucleor is a typed systems language whose **standard library is a working
scientific stack** — linalg, FFT, ODE, stats, optimization, quantum
simulation, control, robotics, ML helpers — and whose **compiler emits
direct LLVM IR** with ownership, effects, and real-time diagnostics
promoted to hard errors. The compiler is **self-hosted** with a
fixed-point bootstrap, so every change has to keep compiling itself.
You write `import "stdlib/rods/linalg.nr"` and you get BLAS-class
operations as part of the language, not a third-party crate you have
to find, vet, and pin.

## What no incumbent does as well

1. **Scientific surface in the std lib, not as packages.** Linalg, FFT,
   ODE, stats, signal, optimization, quantum simulation, and a control
   stack ship in the language tree at `stdlib/rods/`. Versioning is the
   language's versioning. There is no "which crate is canonical" tax.

2. **Ownership + effects + real-time, on a tiny syntax.** Every
   diagnostic surface (OWN-NNN ownership, EFF-NNN effects, RT-NNN
   real-time, TYP-NNN types, PERF-NNN performance, NUM-NNN numeric)
   is a release gate. `@hot`, `@rt`, `@law`, `@layout`, `@safety`
   are first-class attributes. The full code list is at
   `docs/spec/Nucleor_Error_Codes.md`.

3. **LLVM IR you can read.** The compiler emits textual `.ll` with a
   stable shape. `nuc dump-ir foo.nr` shows you exactly what the
   backend will see. There is no opaque MIR or HIR in the middle.

4. **A bootstrap loop a single person can inspect.** Source seed →
   stage-1 binary → stage-2 binary, with `tools/check_self_host_md5.sh`
   enforcing byte-identity at the IR layer. The seed regen path is
   `docs/internals/bootstrap.md`. Cold self-compile is ~5s on Linux.

## Honest limitations

- **Single-platform release gates today.** Windows and Linux are
  release-gated; macOS is experimental and not in the CI matrix.
- **No package manager.** Rods live in-tree; cross-project sharing is
  copy-and-import. A registry is on the roadmap, not in v1.1.
- **`@law(...)` rewrites are scaffolded, not active.** The metadata
  pass parses and surfaces law annotations, but call-site rewrites
  and law-driven property tests are roadmap work. The architecture
  doc (`docs/architecture.md:91-95`) is explicit about this.
- **Const-generic dimensions don't exist yet.** `Matrix<R, C>`-style
  shape checking needs RFC-0034. Today `mat_mul(&A, &B)` accepts any
  two matrices; runtime checks catch shape mismatches.
- **GC-free, but ownership is the cost.** OWN-NNN diagnostics are
  strict — moves, partial moves, borrow-after-move are hard errors.
  This is the same trade Rust makes; if you don't want it, you don't
  want this language.

## Evidence the compiler is real, not slideware

- **Self-hosted, with fixed-point regen.** Stage-2 output is
  byte-identical to the input stage-2 binary; this is enforced on
  every push.
- **1660+ verifier steps.** `bash tools/verify.sh` runs the suite
  (ABI parity, fixture builds, ownership/effect/RT diagnostic
  fixtures, drift checks). Tagged PASS/SKIP/FAIL breakdown lands on
  every run.
- **Runtime benchmarks committed.** `examples/29_scientific_benchmark.nr`
  + `docs/benchmarks.md` show measured numbers against reference
  implementations.

## When Nucleor is the wrong choice

- You want a curated package ecosystem with semver and a registry.
  Rust, Go, and Python beat Nucleor here.
- You're targeting wasm, ARM bare-metal, or non-x86-64. The current
  release line is x86_64 Linux + Windows.
- You want a GC and don't care about ownership errors. Pick Go, OCaml,
  or Kotlin.
- You want an established community. Nucleor is small and pre-1.5.

## When Nucleor is a fit

- You write numerical / scientific / control code and find C++ painful,
  Python slow, Rust verbose for the math you actually want to write.
- You want a language where the compiler is a few thousand lines you
  can actually read.
- You care about LLVM IR being legible and the bootstrap being
  inspectable.
- You're OK shipping with a small std-lib-as-language ecosystem rather
  than waiting for crate maturity.

## Start here

- `docs/getting-started.md` — fresh clone to running program.
- `examples/01_hello.nr` through `examples/30_typed_matrix.nr` — read
  in order; each is a few dozen lines.
- `docs/architecture.md` — how a `.nr` file becomes an `.exe`.
- `bash tools/verify.sh` — see what we gate on.
