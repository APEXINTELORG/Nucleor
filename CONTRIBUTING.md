# Contributing To Nucleor

Thanks for helping improve Nucleor. This project is a self-hosted compiler, so
changes are expected to include proof that the bootstrap chain still closes.

## Quick Start

```bash
git clone https://github.com/APEXINTELORG/Nucleor
cd Nucleor
```

Windows:

```powershell
.\nuc.bat build examples\01_hello.nr -o hello
.\target\hello.exe
```

Linux:

```bash
bash tools/bootstrap_linux.sh
./nuc build examples/01_hello.nr -o hello
./target/hello
```

## Validation

Before opening a pull request, run the narrowest useful test for your change.
For release-sensitive changes, run the canonical gate:

```bash
bash tools/verify.sh --no-color -j 4
```

Compiler or bootstrap changes should also run:

```bash
bash tools/check_self_host_md5.sh
```

If you change `compiler/*.nr`, `stdlib/runtime/*.c`, bootstrap files, or the
launchers, include the relevant command output in the pull request.

## Rebuilding The Compiler

Windows:

```powershell
.\nuc.bat build compiler\nucleor_s1_compiler.nr -o nucleor
.\target\nucleor.exe --version
```

Linux:

```bash
./nuc build compiler/nucleor_s1_compiler.nr -o nucleor
./target/nucleor --version
```

The committed Windows bootstrap binary is `bin/nucleor.exe`. Linux binaries are
reproducible from the seed and are not committed.

## Pull Request Expectations

- Keep changes focused.
- Add or update tests for behavior changes.
- Update docs when user-facing behavior changes.
- Preserve the self-host fixed point for compiler changes.
- Do not include local paths, machine-specific logs, generated timing CSVs, or
  temporary build artifacts.
- Do not commit optional local binaries such as `bin/nucleor_tools.exe` or
  Linux `bin/nucleor`.

## Code Style

- Nucleor source: 4-space indentation, snake_case functions and variables,
  PascalCase structs/enums.
- C runtime: portable C with Windows and POSIX branches kept explicit.
- Documentation: GitHub-flavored Markdown, current commands, and public-facing
  context.

## Reporting Issues

Please include:

- Nucleor version (`nuc --version`, `.\nuc.bat --version`, or
  `bin/nucleor.exe --version`).
- LLVM version (`clang --version`).
- Operating system.
- Minimal `.nr` reproducer.
- Expected and actual behavior.
- Full command output.

Security-sensitive reports should follow [SECURITY.md](SECURITY.md), not a
public issue.
