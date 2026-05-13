# Nucleor

**Nucleor 1.1.0 is a self-hosted systems programming language with an LLVM
backend and a scientific-computing standard library.**

```nr
fn main() -> i64 {
    print("Hello, Nucleor!");
    return 0;
}
```

```powershell
.\nuc.bat build examples\01_hello.nr -o hello
.\target\hello.exe
```

```bash
./nuc build examples/01_hello.nr -o hello
./target/hello
```

## What It Is

Nucleor is a compact Rust-adjacent language with ownership checks, typed
standard-library rods, LLVM IR emission, and a self-hosting compiler written in
Nucleor. The repository includes the Windows bootstrap binary and a portable
LLVM IR seed for Linux bootstrap.

The standard library currently includes about 290 rods and 190 C runtime files.
It covers the core language runtime, collections, files, strings, time, math,
linear algebra, FFT, statistics, ODE/PDE utilities, robotics, control, quantum
simulation, ML-oriented helpers, codecs, sockets, and optional FFI bridges.

## Platform Support

| Host | Status | First-use path |
|---|---|---|
| Windows x86_64 | Supported | Uses committed `bin/nucleor.exe` through `nuc.bat`. |
| Linux x86_64 | Supported | Builds `bin/nucleor` from `bootstrap/nucleor_s1_seed.ll` with `tools/bootstrap_linux.sh`. |
| macOS | Experimental | The POSIX bootstrap path is present, but this release is not macOS-gated. |

Nucleor requires LLVM 18.x. Set `NUCLEOR_CLANG_PATH` to a specific `clang` or
`clang.exe`, or set `LLVM_SYS_180_PREFIX` to an LLVM installation root.

## Quick Start

### Windows

```powershell
git clone https://github.com/APEXINTELORG/Nucleor
cd Nucleor

.\nuc.bat --version
.\nuc.bat build examples\01_hello.nr -o hello
.\target\hello.exe
```

### Linux

```bash
git clone https://github.com/APEXINTELORG/Nucleor
cd Nucleor

bash tools/bootstrap_linux.sh
./nuc --version
./nuc build examples/01_hello.nr -o hello
./target/hello
```

## Language Highlights

- Self-hosted compiler with fixed-point bootstrap verification.
- LLVM backend with native executable output.
- Ownership, move, definite-assignment, Sendable, FFI-null, unsafe, and effect
  diagnostics promoted to hard errors in the v1 line.
- Structs, enums, traits, impls, generics, closures, pattern matching,
  attributes, typed units, contracts, and real-time annotations.
- Standard-library rods for numerics, robotics, ML, quantum simulation,
  systems IO, data structures, codecs, plotting, and optional Rust/Python/GPU
  integration surfaces.
- Tooling for build, run, test, check, stage dumps, diagnostic explanation,
  manifests, packaging, release checks, and reproducibility checks.

## Verification

The release gate is the Bash verifier:

```bash
bash tools/verify.sh --no-color -j 4
```

Focused bootstrap proof:

```bash
bash tools/check_self_host_md5.sh
```

The current v1.1.0 release artifacts have been validated with:

- Windows full verifier: `PASS=1653`, `SKIP=9`, `FAIL=0`.
- Windows strict cold-compile gate: cold self-host compile `3.95s`,
  hot compile `0.12s`, compiler RSS `352 MB` under the `360 MB` ceiling.
- Linux hosted correctness gate: bootstrap, self-host fixed point, full
  `verify.sh`, and rust_bridge ownership harness green on Ubuntu 24.04 with
  LLVM 18.

Hosted GitHub Linux/Windows timing is treated as correctness evidence, not as a
pinned performance baseline. Perf baseline locking belongs on a stable
self-hosted or otherwise pinned runner.

## Documentation

- [Getting started](docs/getting-started.md)
- [Language tour](docs/language-tour.md)
- [Language reference](docs/language-reference.md)
- [Architecture](docs/architecture.md)
- [Feature inventory](docs/NUCLEOR_FEATURE_INVENTORY.md)
- [Benchmarks and performance gates](docs/benchmarks.md)
- [Self-host integrity](docs/SELF_HOST_INTEGRITY.md)
- [Release signing](docs/release-signing.md)
- [Release checklist](docs/release-checklist.md)
- [Examples](examples/README.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Security reports should follow
[SECURITY.md](SECURITY.md).

## License

Nucleor is licensed under the Apache License, Version 2.0. See
[LICENSE](LICENSE) and [NOTICE](NOTICE).
