# Getting Started

This guide takes a fresh clone to a running Nucleor program.

## Requirements

- Windows 10/11 x86_64 or Linux x86_64.
- LLVM 18.x with `clang` and `lld` available.
- Git.
- Optional: Rust, only for the `rust_bridge` rod.
- Optional: CUDA, only for CUDA-backed runtime experiments.

The launchers resolve clang in this order:

1. `NUCLEOR_CLANG_PATH`
2. `LLVM_SYS_180_PREFIX/bin`
3. Common platform install paths
4. `PATH`

## Install On Windows

```powershell
git clone https://github.com/APEXINTELORG/Nucleor
cd Nucleor

.\nuc.bat --version
```

The repository ships `bin\nucleor.exe`, the Windows bootstrap compiler. You do
not need to rebuild the compiler before building your first program.

## Install On Linux

```bash
git clone https://github.com/APEXINTELORG/Nucleor
cd Nucleor

bash tools/bootstrap_linux.sh
./nuc --version
```

Linux does not use the Windows `.exe`. The bootstrap script compiles the
portable LLVM IR seed in `bootstrap/nucleor_s1_seed.ll` with the C runtime,
produces `bin/nucleor`, and checks the self-host fixed point.

## Hello, Nucleor

`examples/01_hello.nr`:

```nr
fn main() -> i64 {
    print("Hello, Nucleor!");
    return 0;
}
```

Build and run it:

```powershell
.\nuc.bat build examples\01_hello.nr -o hello
.\target\hello.exe
```

```bash
./nuc build examples/01_hello.nr -o hello
./target/hello
```

Expected output:

```text
Hello, Nucleor!
```

## What Happened

The compiler:

1. Lexed and parsed the `.nr` file.
2. Type-checked and ran safety/effect analysis.
3. Lowered the AST to Nucleor IR.
4. Emitted LLVM textual IR into `target/`.
5. Invoked clang to link the IR with `stdlib/runtime/nucleor_llvm_rt.c` and
   any runtime files requested by imported rods.

For introspection:

```bash
nuc stage-dump tokens examples/01_hello.nr
nuc stage-dump ast examples/01_hello.nr
nuc stage-dump ir examples/01_hello.nr
nuc stage-dump all examples/01_hello.nr
```

Use `.\nuc.bat` instead of `nuc` for those commands on Windows unless the repo
root is already on your `PATH`.

## Verify Your Setup

Fast compiler identity check:

```bash
bash tools/check_self_host_md5.sh
```

Full release-style gate:

```bash
bash tools/verify.sh --no-color -j 4
```

On Windows, run the Bash gate from Git Bash or another Bash environment. The
PowerShell scripts are retained for native maintenance workflows, but
`tools/verify.sh` is the canonical cross-platform gate.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `clang: command not found` | LLVM 18 is missing or not discoverable. | Install LLVM 18 and set `NUCLEOR_CLANG_PATH` or `LLVM_SYS_180_PREFIX`. |
| `bin\nucleor.exe not found` on Windows | The bootstrap binary is missing. | Re-clone, or run `pwsh -NoProfile -File tools\bootstrap_windows.ps1 -Run -Force -Verify`. |
| `bin/nucleor not found` on Linux | The Linux bootstrap has not been run. | Run `bash tools/bootstrap_linux.sh`. |
| Rust interop examples fail to link | The optional Rust bridge was not built. | Run `cargo build --release` in `stdlib/rods/rust_bridge`. |
| Build succeeds but executable is missing | clang link failed after IR emission. | Check the `clang exit N` output and `.nuc_cache/clang_link.*.log`. |
