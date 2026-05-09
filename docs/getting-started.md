# Getting Started

Five minutes from a fresh clone to a running Nucleor program.

## Prerequisites

- **Windows 10/11, x86_64** is the primary supported host. The shipped bootstrap binary `bin/nucleor.exe` targets `x86_64-pc-windows-msvc`. POSIX support (Linux/macOS) shipped in v0.3 — the platform-portable C runtime is at `stdlib/runtime/nucleor_llvm_rt.c`; POSIX adopters bootstrap from `bootstrap/nucleor_s1_seed.ll` via `tools/bootstrap_linux.sh`. Embedded cross-compile targets (Cortex-M4F, RV32IMAC) are forward-roadmap (v0.6.x).
- **LLVM 18.x** with `clang.exe`. The default install path is `C:\Program Files\LLVM\bin`.
  - Easiest install: `winget install LLVM.LLVM` or download from https://github.com/llvm/llvm-project/releases.
  - If LLVM lives elsewhere, set `LLVM_SYS_180_PREFIX` (pointing at the install root) or `NUCLEOR_CLANG_PATH` (full path to `clang.exe`) before invoking `nuc`.
- **Optional: Rust toolchain** (only if you want to use `stdlib/rods/rust.nr` for regex/base64 via the bundled `rust_bridge` crate).
- **Optional: CUDA Toolkit 12.x** (only if you want the GPU runtime files in `stdlib/runtime/cuda_rt.cu` and `taylor_gpu_rt.cu`).

## Install

```
git clone https://github.com/APEXINTELORG/Nucleor
cd Nucleor
```

That's it. The bootstrap binary `bin/nucleor.exe` is included in the repo so you don't need to build the compiler from source on first use.

Optionally add the repo root to `%PATH%` so you can invoke `nuc` from any directory:

```
setx PATH "%PATH%;%CD%"
```

## Hello, Nucleor

The repo ships with `examples/01_hello.nr`:

```nr
fn main() -> i64 {
    print("Hello, Nucleor!");
    return 0;
}
```

Build and run it:

```
nuc build examples\01_hello.nr -o hello
target\hello.exe
```

You should see:

```
Hello, Nucleor!
```

## What just happened

`nuc.bat` is a tiny launcher. It resolved `clang.exe` (so the compiler can link), then handed your file to `bin/nucleor.exe`. The compiler:

1. Lexed and parsed `01_hello.nr` into an AST
2. Lowered the AST to Nucleor IR
3. Ran the algebraic-rewrite optimizer
4. Emitted LLVM IR to `target/hello.ll`
5. Invoked `clang` to link the IR with `stdlib/runtime/nucleor_llvm_rt.c` (the always-linked core runtime) and produce `target/hello.exe`

For a deeper view of any of these stages, try:

```
nuc stage-dump tokens examples\01_hello.nr
nuc stage-dump ast    examples\01_hello.nr
nuc stage-dump ir     examples\01_hello.nr
nuc stage-dump all    examples\01_hello.nr
```

## Next steps

- **Browse the examples.** The repo ships ~27 numbered examples in `examples/01_hello.nr` through `examples/27_effects_with_tour.nr`, organised in 6 tiers by language-feature focus (language tour → numerics → stdlib showcase → robotics RT → v0.4 features → v0.6 features). Tier 6 covers the v0.6.x surfaces — RFC-0014 `#[max_depth]` proven recursion shapes (`26_max_depth_tour.nr`) and RFC-0033 `with [...]` effects-in-function-types substrate (`27_effects_with_tour.nr`). Five `examples/showcase/*.nr` programs — `lorenz`, `vqe_h2`, `market_maker`, `wing_simulator`, `robotic_arm` — combine multiple rods into end-to-end simulations. The full numbered list lives in `tools/examples.list`.
- **Read the [language tour](language-tour.md)** for syntax and semantics by example.
- **Read the [language reference](language-reference.md)** for the full grammar, type system, and attribute catalog.
- **Run the tests** to confirm everything works on your machine: `nuc test tests/`.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `clang: command not found` | LLVM not installed or not on PATH | Install LLVM 18.x; the launcher will find it automatically if it's at `C:\Program Files\LLVM` |
| `bin\nucleor.exe not found` | Repo wasn't cloned with binary | The bootstrap binary is committed to the repo. If missing, re-clone, then on Windows run `tools\bootstrap_windows.ps1 -Run -Force` (or on POSIX `tools/bootstrap_linux.sh`) — both rebuild from the committed `bootstrap/nucleor_s1_seed.ll` without an existing `nuc`. (Note: `nuc build ... -o bin\nucleor.exe` always lands the output in `target\nucleor.exe` — the basename is preserved but the directory is not.) |
| `LNK1181: cannot open input file 'nucleor_rust_bridge.lib'` | Trying to use `stdlib/rods/rust.nr` without building the Rust bridge | `cd stdlib\rods\rust_bridge && cargo build --release` |
| Build succeeds but `target\hello.exe` is missing | The compiler emitted IR but linking failed | Look for `clang exit N` in the output and address the underlying linker error |
