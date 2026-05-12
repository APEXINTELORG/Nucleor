# Nucleor CLI Maturity Spec

Date: 2026-05-10
Status: public roadmap/specification
Scope: user-facing CLI, installation behavior, shell ergonomics, machine-readable command surface, REPL direction, and validation gates.

This document is a product/toolchain spec. It does not change language syntax. It defines what the Nucleor command-line experience should become so the language feels installable, reliable, scriptable, and mature.

## 1. Current State

Evidence source: the v1.1.0 public release line.

Observed working entry points:

- `bin/nucleor.exe --version` prints `nucleor 1.1.0 (self-hosted, llvm backend)`.
- `bin/nucleor.exe --help` prints a broad `nuc <command>` help surface.
- `nuc.bat` on Windows resolves `clang.exe` and forwards all arguments to `bin\nucleor.exe`.
- `nuc` on POSIX resolves clang and forwards all arguments to `bin/nucleor`.
- `stdlib/rods/cli.nr` provides a CLI parsing rod for user programs.
- The compiler runtime exposes `args_count()` / `args_get()` to Nucleor programs.

Advertised command families from `bin/nucleor.exe --help`:

- Build: `init`, `build`, `build-fast`, `build-strict`, `build-shared`, `run`, `emit`, `build-wasm`, `build-ptx`, `verify-reproducible`.
- Developer: `test`, `bench`, `perf`, `bootstrap`, `stage-dump`, `summary`, `query`, `abi`, `evidence`, `impact`, `graph`, `doc`, `profile`, `lock`, `install`, `publish`, `registry`, `sage`.
- Analysis: `check`, `explain`.
- Governance: `audit`, `policy`, `certify`, `translate`.
- Utilities: `clean`, `scram`, `fix`, `gen-headers`, `zen`, `mco`.

Additional observed surfaces:

- `bin/nucleor.exe --lsp-mode` emits LSP capability JSON, but this is not listed as the normal user command.
- `bin/nucleor.exe tools` exists and documents tool installation under `$NUC_HOME`, but it is not listed in `--help`.
- `nuc_router.ps1` contains a richer wrapper-level command map including `doctor`, `commands`, `fmt`, `release`, and `lsp`.

Current inconsistencies:

- `nuc.bat doctor` and `bin/nucleor.exe doctor` return `Unknown command: doctor`.
- `nuc.bat commands` and `bin/nucleor.exe commands` return `Unknown command: commands`.
- `nuc_router.ps1 commands --json` works, but the normal Windows launcher does not route to it.
- `nuc_router.ps1 doctor --json` expects stale target paths in some flows, while the current release path uses `bin\nucleor.exe` and `compiler\nucleor_s1_compiler.nr`.
- `nuc_router.ps1 help` fails for the same stale `target\nucleor.exe` path.
- `deps` exists in tools-suite code, but `bin/nucleor.exe deps` returns `Unknown command: deps`.
- The product has no REPL command today.
- There is no confirmed installer-level guarantee that `nuc` or `nucleor` is available from every new PowerShell/CMD session after installation.

## 2. Product Direction

Nucleor should have a mature CLI. This is required for production readiness.

The CLI should not be a thin afterthought around the compiler. It should be the primary operating surface for:

- building;
- running;
- checking;
- testing;
- benchmarking;
- packaging;
- documentation;
- diagnostics;
- formatter/LSP/editor integration;
- provenance/certification;
- environment repair;
- shell completion;
- machine-readable automation.

The interactive Python-like experience should be explicit as `nuc repl`, not the default behavior of bare `nuc`. Bare `nuc` should stay deterministic and print concise help plus the highest-value next commands. Production compilers normally prioritize predictable command routing; REPL is a mode.

Recommended executable names:

- `nuc`: primary short tool, like `cargo`, `go`, `rustc`, `zig`.
- `nucleor`: full-name alias installed beside `nuc`.
- `bin/nucleor.exe`: implementation binary, not the primary docs spelling.

## 3. CLI Design Principles

1. One canonical command contract.

   The command list shown in help, the machine-readable `commands --json`, README examples, docs, wrapper scripts, and verifier inventory must agree.

2. No shadow surface.

   A command must not exist only in `nuc_router.ps1` unless the normal launcher routes to it. A command must not be documented unless it dispatches on release artifacts.

3. No silent flag swallowing.

   Unknown flags must fail with a clear diagnostic and non-zero exit code. Typos such as `--no-cahce` must never compile as if accepted.

4. Human and machine modes must both be stable.

   Human output may be polished. JSON/SARIF/JSONL output must be schema-versioned and stable.

5. Project mode must be first-class.

   `nuc build`, `nuc run`, `nuc test`, and `nuc check` must work from a directory with `Nucleor.toml` and no explicit source path.

6. Installer behavior must be testable.

   A fresh shell after installation must resolve `nuc`, `nucleor`, `clang` or the configured LLVM path, the sysroot, and the runtime objects.

7. The fast path stays fast.

   The default developer compile path should remain under the release performance budget. Release optimization is separate and explicit.

8. The CLI must expose recovery.

   `nuc doctor`, `nuc clean`, `nuc cache`, `nuc bootstrap status`, and actionable errors should make local toolchain repair obvious.

## 4. Proposed Command Surface

### 4.1 Global Flags

These should work on every command unless explicitly invalid:

- `-h`, `--help`
- `-V`, `--version`
- `--color auto|always|never`
- `--json`
- `--quiet`
- `--verbose`
- `--trace`
- `--config <path>`
- `--offline`
- `--no-cache`
- `--cache-dir <path>`

JSON output should include:

- `schema_version`
- `tool`
- `tool_version`
- `command`
- `cwd`
- `status`
- `diagnostics`
- `artifacts`
- `timings_ms` where relevant

### 4.2 Core Commands

Required for the first mature CLI release:

- `nuc help [command]`
- `nuc commands [--json]`
- `nuc version [--json]`
- `nuc doctor [--json]`
- `nuc init [name]`
- `nuc new [name]`
- `nuc build [file]`
- `nuc run [file] [-- <program args>]`
- `nuc check [file]`
- `nuc test [file]`
- `nuc bench [file]`
- `nuc clean [--cache|--all]`
- `nuc explain <CODE>`

Notes:

- `init` can keep current behavior.
- `new` should be a friendly alias for creating a directory and project, matching common ecosystem expectations.
- `run -- <program args>` is important because Nucleor programs already have `args_count()` and `args_get()`.

### 4.3 Build Commands

Required:

- `nuc build [file] [-o name]`
- `nuc build --release [file]`
- `nuc build --tier 0|1|2 [file]`
- `nuc build --emit llvm [file]`
- `nuc build --no-link [file]`
- `nuc build --target <triple> [file]`
- `nuc build-shared [file]`
- `nuc build-wasm [file]`
- `nuc build-ptx [file]`
- `nuc verify-reproducible [file]`

Build-tier contract:

- Tier 0: fast developer compile, clang `-O0`, target sub-4.25s for self-host compiler workload on documented release hosts.
- Tier 1: balanced compile/runtime profile, likely `-O1` or a curated LLVM pipeline.
- Tier 2 / `--release`: optimized native output, clang/LLVM `-O3` or future tuned pipeline, slower than default by design.

Required artifact metadata:

- source path;
- output path;
- target triple;
- opt tier;
- clang/LLVM path and version;
- cache key;
- runtime object key;
- Nucleor compiler version;
- deterministic build hash when requested.

### 4.4 Analysis Commands

Required:

- `nuc check [file] [--check ownership,type,source,taint,effect]`
- `nuc check --json`
- `nuc check --sarif`
- `nuc explain <CODE> [--json]`
- `nuc summary [file] [--json]`
- `nuc query [file] [--json]`
- `nuc graph [file] [--json|--dot|--mermaid]`
- `nuc impact [file] --fn <name>`
- `nuc stage-dump tokens|ast|typed|ir|all <file> [--json]`

Policy:

- The same semantic checks must not disagree between `build`, `check`, `build-strict`, and tools-suite paths.
- If a checker is available only in a slower strict path, the CLI must say so explicitly.

### 4.5 Test And Benchmark Commands

Required:

- `nuc test [file]`
- `nuc test --list`
- `nuc test --filter <pattern>`
- `nuc test --isolation process|thread`
- `nuc test --check-laws`
- `nuc bench [file] --iterations <n> --warmup <n>`
- `nuc perf [file] [--json]`
- `nuc profile run <binary> --iterations <n> [--json]`

Future:

- `nuc watch test`
- `nuc watch check`
- `nuc test --coverage` if coverage instrumentation lands.

### 4.6 Formatter, LSP, Docs

Required:

- `nuc fmt [file|dir]`
- `nuc fmt --check [file|dir]`
- `nuc lsp --stdio`
- `nuc doc [file] [--out <path>] [--html]`
- `nuc doc --test-list [file]`
- `nuc completions powershell|bash|zsh|fish`

Current `--lsp-mode` should become an internal implementation detail behind `nuc lsp --stdio`. The public command should not require users or editors to know hidden flags.

### 4.7 Package And Workspace Commands

Required:

- `nuc lock [manifest] [--json]`
- `nuc add <pkg>` aliasing package install into `Nucleor.toml`
- `nuc remove <pkg>`
- `nuc update [pkg]`
- `nuc install [alias] <path|pkg|pkg@version>`
- `nuc publish [manifest] --registry <dir> [--dry-run] [--sign]`
- `nuc registry list|search|versions|verify`
- `nuc registry remote add|list|remove`
- `nuc deps graph [manifest] --format text|json|dot|mermaid`
- `nuc metadata --json`

Workspace future:

- `nuc workspace members`
- `nuc build --workspace`
- `nuc test --workspace`
- `nuc check --workspace`

### 4.8 Governance And Certification

Required:

- `nuc audit [file]`
- `nuc policy [file] [level]`
- `nuc certify [file]`
- `nuc evidence [file]`
- `nuc sbom [file|manifest]`
- `nuc provenance [artifact]`
- `nuc release sign|verify|attest`

The governance commands are a differentiator for Nucleor. They should have strong JSON output and reproducible evidence files, not only human reports.

### 4.9 Toolchain Commands

Required:

- `nuc doctor [--json]`
- `nuc toolchain list`
- `nuc toolchain detect`
- `nuc toolchain set clang <path>`
- `nuc cache stats`
- `nuc cache clean`
- `nuc bootstrap status`

Current `nuc tools` can either become:

- `nuc tool install/list/uninstall`, or
- `nuc tools install/list/uninstall`.

Pick one spelling and make help, docs, and launcher behavior match.

### 4.10 REPL

Recommended, not required for the immediate CLI repair:

- `nuc repl`

Minimum REPL:

- expression evaluation;
- `let` bindings retained across lines;
- `:type <expr>`;
- `:explain <CODE>`;
- `:load <file>`;
- `:reset`;
- `:help`;
- `:quit`;
- `:time <expr>`;
- multi-line function entry;
- temp-file compile/run fallback if true in-memory eval is not ready.

The first REPL can be compile-backed instead of JIT-backed. The mature direction is to eventually reuse parser/typechecker/IR lowering directly with a persistent session environment.

Bare `nuc` should not silently enter the REPL in production builds. It should print concise help. `nuc repl` is explicit and script-safe.

## 5. Installation Contract

After install, a fresh PowerShell/CMD/Bash shell must support:

```text
nuc --version
nucleor --version
nuc doctor
nuc build examples/01_hello.nr -o hello
```

Windows installer responsibilities:

- install `nuc.exe` or `nuc.bat` shim;
- install `nucleor.exe` alias or shim;
- add install bin directory to user or machine PATH;
- detect LLVM/clang or offer to install/configure it;
- initialize `%LOCALAPPDATA%\Nucleor`;
- preserve existing user config;
- expose uninstall cleanly.

POSIX installer responsibilities:

- install `nuc` and `nucleor` shims into a selected bin directory;
- detect LLVM/clang;
- initialize `$HOME/.nucleor`;
- install shell completions when requested;
- provide non-root install mode.

## 6. Architecture Recommendation

Short term:

- Keep `bin/nucleor.exe` as the canonical compiler implementation.
- Update `nuc.bat` and `nuc` so they route all documented commands correctly.
- Either remove `nuc_router.ps1` from the product path or fix it to use the current `bin/` and `compiler/` layout.
- Implement `doctor` and `commands --json` in the canonical path.

Medium term:

- Introduce a very small front-controller layer whose only job is CLI parsing, environment resolution, shell completions, and command dispatch.
- Keep compiler semantics in the self-hosted compiler.
- Keep wrappers thin and cross-platform.

Long term:

- Move toward one native `nuc` executable containing:
  - stable argument parsing;
  - command registry;
  - schema-versioned JSON;
  - environment detection;
  - compiler invocation;
  - tool/package subcommands.

Avoid:

- multiple independent command tables;
- wrapper-only commands that are not tested through the shipped launcher;
- tools-suite-only commands advertised by the main binary unless the main binary can route them.

## 7. Acceptance Gates

Every release candidate must pass:

1. Version parity

   - `nuc --version`
   - `nucleor --version`
   - `bin/nucleor.exe --version`
   - source `compiler_version_label()`
   - CHANGELOG/RELEASES entry

2. Help coverage

   - Every command in `nuc help` dispatches.
   - Every command in `nuc commands --json` dispatches.
   - `nuc help` and `nuc commands --json` agree.
   - README quickstart uses only commands that dispatch.

3. Unknown flag discipline

   - Unknown flags fail.
   - Missing flag values fail.
   - Wrong enum values fail.
   - Typos never silently compile.

4. Fresh-shell install proof

   - New shell resolves `nuc`.
   - New shell resolves `nucleor`.
   - `nuc doctor` identifies clang and runtime paths.
   - A hello-world project builds and runs outside the repo root.

5. Project mode proof

   - `nuc init tmp_project`
   - `cd tmp_project`
   - `nuc build`
   - `nuc run`
   - `nuc check`
   - `nuc test`

6. Machine output proof

   - `nuc commands --json`
   - `nuc doctor --json`
   - `nuc check --json`
   - `nuc check --sarif`
   - `nuc perf --json`

7. Cross-host proof

   - Windows PowerShell.
   - Windows CMD.
   - Git Bash / MSYS where supported.
   - Native Linux Bash.

8. Performance proof

   - Default cold compile remains within the documented budget.
   - Release tier reports clang/LLVM optimization timing separately.
   - Cache hits/misses are visible under `--cache-stats`.

9. Bootstrap proof

   - `nuc bootstrap status`.
   - self-host fixed point.
   - drift gates.
   - generated `bin/` and `bootstrap/` artifacts match source.

## 8. Immediate Repair Plan

Phase A: define the canonical surface.

- Decide whether `nuc_router.ps1` remains product code or becomes retired/dev-only.
- Add `commands --json` to the normal launcher path.
- Add `doctor --json` to the normal launcher path.
- Make `help`, `commands --json`, README, and verify command inventory agree.

Phase B: repair existing inconsistencies.

- Fix `nuc_router.ps1` stale `target/` assumptions if it remains.
- Wire `doctor` to current `bin/nucleor.exe`, `compiler/nucleor_s1_compiler.nr`, LLVM, runtime object cache, and optional backends.
- Either expose `tools` in help or remove it from the public surface.
- Either expose `--lsp-mode` as internal-only behind `nuc lsp --stdio`, or keep it undocumented and add `lsp`.
- Decide whether `deps` is public. If yes, route it. If no, remove/keep it tools-suite-internal.

Phase C: installer and shell maturity.

- Add `nuc install-self` or installer scripts for PATH setup.
- Add `nucleor` alias.
- Add shell completions.
- Add fresh-shell validation script.

Phase D: REPL.

- Ship `nuc repl` as compile-backed first.
- Add persistent bindings and `:type`, `:load`, `:explain`, `:time`.
- Treat full JIT/in-memory REPL as a later optimization.

## 9. Non-Goals

These are explicitly out of scope for the CLI maturity spec:

- changing Nucleor language syntax;
- adding Python syntax translation;
- weakening diagnostics to improve CLI appearance;
- making `--release` fast by pretending it is `-O0`;
- requiring Python/npm for normal `nuc build`;
- making a GUI mandatory.

## 10. Bottom Line

Nucleor already has a substantial command-line surface. The gap is not "no CLI." The gap is that the CLI surface is split across the self-hosted binary, thin launchers, a stale PowerShell router, tools-suite-only code paths, and documentation. The mature path is to make one canonical, installable, scriptable command contract and then add REPL/editor/package polish on top of it.
