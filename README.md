# Nucleor

**A self-hosted systems language with algebraic optimization and proof-friendly numerics.**

Nucleor is a small, statically-typed language that compiles to native code through LLVM. The compiler is written in Nucleor itself — every release rebuilds the compiler from its own source as part of CI. The optimizer understands user-declared algebraic laws (`@law(commutative, associative, identity=0)`), enforces strict performance budgets on hot paths (`@hot`), and ships with a runtime that includes a quantum-circuit simulator, validated Taylor-arithmetic primitives, and a working Rust-FFI demonstration.

```nr
fn main() -> i64 {
    print("Hello, Nucleor!");
    return 0;
}
```

```
nuc build examples/01_hello.nr -o hello
target\hello.exe
> Hello, Nucleor!
```

## Why

- **Self-hosted from day one.** The compiler is written in Nucleor and rebuilds itself as a standard CI step. No hidden runtime dependencies; no separate bootstrap language to keep in sync.
- **Algebraic optimization.** Declare a function commutative or associative and the optimizer rewrites call sites accordingly. Identity elimination, idempotence, involution, and fusion are all expressible.
- **Strict performance attributes.** `@hot` enforces no-heap, no-format, no-indirect-dispatch in a function's body and surfaces violations as compile-time diagnostics.
- **Proof-friendly numerics.** Bundled interval and Taylor-arithmetic runtimes for code where bit-exact bounds matter (PDE solvers, quantum simulation, formal verification pipelines).
- **Real interop.** The shipping `rust_bridge` demonstrates calling Rust crates (regex, base64, hashing) from Nucleor through the C ABI. The same pattern works for any language with `extern "C"` static-library output.

## Install

Prerequisites: **Windows 10/11 x86_64**, **LLVM 18.x** with `clang.exe`. CUDA Toolkit and Rust toolchain are optional.

```
git clone https://github.com/APEXINTELORG/Nucleor
cd Nucleor
nuc build examples/01_hello.nr -o hello
target\hello.exe
```

The bootstrap binary `bin/nucleor.exe` is committed to the repo, so you do not need to build the compiler from source on first use. The `nuc.bat` launcher resolves `clang.exe` from `NUCLEOR_CLANG_PATH`, then `LLVM_SYS_180_PREFIX/bin`, then `C:\Program Files\LLVM\bin`, then plain PATH.

POSIX (Linux/macOS) support is planned for v1.1. The `nuc` shell stub is shipped now to keep the layout stable.

## What's in the box

| Path | Purpose |
|---|---|
| `bin/nucleor.exe`         | The bootstrap compiler binary |
| `compiler/`               | The compiler's own Nucleor source (`nucleor_s1_compiler.nr`, `nucleor_tools_suite.nr`) |
| `stdlib/runtime/`         | Always-linked C runtime (`nucleor_llvm_rt.c`) plus opt-in domain runtimes (FFT, hashmap, JSON, crypto, tensor, ...) |
| `stdlib/rods/`            | Standard library rods (Nucleor `.nr` wrappers + their `_rt.c` runtimes): strings, fmt, json, regex, quantum, neural-network, GNN, concurrency, time, base64, bitwise, math, cli, log, test, ... |
| `stdlib/rods/rust_bridge/`| A working Rust crate demonstrating C-ABI interop |
| `examples/01..07_*.nr`    | Seven runnable demos, one per major feature |
| `tests/`                  | 24 self-contained `.nr` tests across language, attributes, runtime, rods, and negative cases |
| `docs/`                   | Full reference: getting-started, language tour, language reference, rods + runtime, architecture, benchmarks |
| `nuc.bat`, `nuc_router.ps1` | Windows launcher and command router |

## Tour by example

- [`examples/01_hello.nr`](examples/01_hello.nr) — the smallest possible program.
- [`examples/02_fib.nr`](examples/02_fib.nr) — recursion + iteration.
- [`examples/03_structs.nr`](examples/03_structs.nr) — structs, fields, mutation.
- [`examples/04_rods.nr`](examples/04_rods.nr) — using stdlib rods (strings + JSON).
- [`examples/05_quantum.nr`](examples/05_quantum.nr) — Bell-state preparation on the bundled quantum simulator.
- [`examples/06_perf_attrs.nr`](examples/06_perf_attrs.nr) — `@hot`, `@law`, `@const_fn`.
- [`examples/07_rust_interop.nr`](examples/07_rust_interop.nr) — Rust regex + base64 via `rust_bridge`.

## Documentation

- [Getting Started](docs/getting-started.md) — install, first build, troubleshooting.
- [Language Tour](docs/language-tour.md) — syntax and idioms by example.
- [Language Reference](docs/language-reference.md) — formal-style spec of types, control flow, attributes, the CLI.
- [Rods and Runtime](docs/rods-and-runtime.md) — what rods exist, how the runtime boundary works, how to write a new rod in C, Rust, or anything else with a C ABI.
- [Architecture](docs/architecture.md) — pipeline (lex → parse → IR → algebraic-rewrite → LLVM → clang), the self-host bootstrap chain, the optimizer.
- [Benchmarks](docs/benchmarks.md) — reproducible numbers from `nuc bench`.

## CLI quick reference

```
nuc init [name]            scaffold a new project
nuc build [file]           compile to native binary
nuc run [file]             compile and run
nuc test [path]            build and run @test / test_* functions
nuc bench [file]           benchmark repeated runs
nuc perf [file]            optimizer + performance diagnostics
nuc check [file]           run all checkers (ownership, type, source, taint, effect)
nuc emit [file]            emit LLVM IR only
nuc stage-dump <stage>     dump compiler stage summaries (tokens|ast|typed|ir|all)
nuc bootstrap status       self-host bootstrap report
nuc help                   full command list
```

## Testing this build

```
nuc test tests/
```

This compiles and runs all 24 tests across `tests/lang/`, `tests/attrs/`, `tests/runtime/`, and `tests/rods/`. The negative tests in `tests/err/` are checked separately by running `nuc build` against them and confirming the expected diagnostic fires.

## Versioning

This is the **v0.1.0** open-source release. The bootstrap binary identifies itself as `Nucleor Compiler 0.2.0-v2` — the V2 designation refers to the second major rewrite of the compiler internals (the rewrite that introduced the algebraic-rewrite optimizer and the V2 attribute set). Future releases will follow semantic versioning starting from v0.1.0.

See [CHANGELOG.md](CHANGELOG.md) for what changed in this release.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The short version: open an issue or PR at https://github.com/APEXINTELORG/Nucleor. We follow the [Contributor Covenant](CODE_OF_CONDUCT.md).

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).

Copyright 2026 Joseph Wescott.
