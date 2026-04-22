# Contributing to Nucleor

Thanks for your interest in contributing. This document explains how to build,
test, and propose changes.

## Quick start

Prerequisites:
- Windows 10/11 x86_64
- LLVM 18.x with `clang.exe` (default install location: `C:\Program Files\LLVM\bin`)
- Git
- Optional: Rust toolchain (for `stdlib/rods/rust_bridge`)
- Optional: CUDA Toolkit 12.x (for GPU runtimes)

Get the source:

```
git clone https://github.com/APEXINTELORG/Nucleor
cd Nucleor
```

Verify your local setup:

```
nuc build examples/01_hello.nr -o hello
target\hello.exe
```

You should see `Hello, Nucleor!`.

## Running the test suite

```
nuc test tests/
```

This compiles and runs all `.nr` test files in `tests/lang/`, `tests/attrs/`,
`tests/runtime/`, and `tests/rods/`. Each test prints `OK <name>` on success or
`FAIL <name>: <reason>` and exits non-zero on failure.

The negative tests in `tests/err/` are checked separately — they should
*fail* to build with a specific diagnostic. Run them with:

```
nuc build tests/err/err_immutable_assign.nr -o _ignored
```

and confirm the expected `OWN-008` (or similar) appears in the output.

## Rebuilding the compiler

The compiler is self-hosted. To rebuild it from source:

```
nuc build compiler\nucleor_s1_compiler.nr -o bin\nucleor.exe.new
```

Smoke-test the new binary, then replace `bin\nucleor.exe`:

```
target\nucleor.exe.new build examples/01_hello.nr -o _smoke
target\_smoke.exe
copy /Y target\nucleor.exe.new bin\nucleor.exe
```

The `bin/nucleor.exe` committed to the repo is the canonical bootstrap binary.
Changes that touch `compiler/*.nr` should include a self-host rebuild commit
(re-running CI confirms the chain still closes).

## Building rust_bridge

The Rust interop demo requires building the Rust crate before
`examples/07_rust_interop.nr` and `tests/rods/rust_interop.nr` can link:

```
cd stdlib\rods\rust_bridge
cargo build --release
cd ..\..\..
```

## Project layout

```
bin/                 prebuilt bootstrap binary
compiler/            self-host compiler source (.nr)
stdlib/runtime/      always-linked + opt-in C runtimes
stdlib/rods/         standard-library rods (.nr wrappers + their _rt.c)
examples/            runnable demos
tests/               curated test corpus
docs/                user-facing documentation
.github/workflows/   CI configuration
```

See [docs/architecture.md](docs/architecture.md) for the compilation pipeline
and self-host bootstrap chain.

## Filing issues

Issues live at https://github.com/APEXINTELORG/Nucleor/issues. When filing, please include:

- Nucleor version (output of `bin/nucleor.exe help` includes the version line)
- LLVM version (`clang --version`)
- Operating system version
- Minimal `.nr` reproduction
- Expected vs. actual behavior
- Full output of the failing command (use `--time-passes` if it's a perf issue)

## Pull requests

1. Fork the repo and create a topic branch off `main`.
2. Make your change. Keep PRs focused — one fix or feature per PR.
3. Add or update tests under `tests/` to cover the change.
4. Run `nuc test tests/` and confirm everything still passes.
5. If you touched `compiler/*.nr`, also run a self-host rebuild
   (see "Rebuilding the compiler" above) and commit the rebuilt
   `bin/nucleor.exe` if it changed.
6. Update `CHANGELOG.md` under an `[Unreleased]` section.
7. Open the PR with a clear title and description; link any related issues.

## Code style

- **Nucleor source (`.nr`)**: 4-space indent, snake_case for functions and
  variables, PascalCase for structs and enums, semicolons after `if`/`while`
  blocks. Match existing patterns in `compiler/nucleor_s1_compiler.nr` and the
  rods.
- **C runtime (`.c`)**: Microsoft-friendly C99. `_CRT_SECURE_NO_WARNINGS` at
  top. `__nucleor_*` for symbols the compiler calls; `nuc_*` or `rods_*` for
  internal helpers.
- **Documentation (`.md`)**: GitHub-flavored Markdown, no trailing whitespace,
  reasonable line wrapping.

Avoid drive-by formatting changes in PRs that aren't about formatting.

## What's in scope vs. out of scope

**In scope** for v0.1.x patches:

- Bug fixes in the compiler, runtime, or rods
- Documentation improvements
- Test additions
- New rods (small, focused, with C source + `.nr` wrapper + a test)

**Out of scope** for v0.1.x (defer to v0.2 / v1.0 milestones):

- Linux / macOS port
- `for` loop syntax, `break`/`continue`
- Generics work
- New CLI subcommands
- Major changes to the optimizer

If you're not sure whether something is in scope, open an issue first to
discuss before doing the implementation work.

## Code of Conduct

Participation is governed by our [Code of Conduct](CODE_OF_CONDUCT.md).
