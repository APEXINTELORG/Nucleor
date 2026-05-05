# Nucleor Bootstrap Contract

> **Status:** Live since v0.2.0; referenced by `nuc bootstrap` since
> v0.2.70. The verify gate enforces the contract on every release —
> a failed self-host rebuild blocks promotion.

This document specifies the boundary conditions Nucleor's compiler
maintains for itself. It is the agreement between the project's
build process and any future contributor or release engineer.

## Stage hierarchy

Nucleor is **self-hosted**. The compiler is written in Nucleor
source (`compiler/nucleor_s1_compiler.nr`, ~10K lines). It builds
itself.

There is exactly one **bootstrap-load-bearing** binary committed to
the repo:

```
bin/nucleor.exe
```

Identifies as `nucleor 0.4.180 (self-hosted, llvm backend)` (build-
internal version; pre-v0.8.280 docs claimed `0.2.0-v2` — that
identity is stale per audit R13-D1, v0.8.280). The current canonical
release is the latest git tag on `main`. `bin/nucleor.exe` is
**stage 1** (self-hosted). There is no stage 0 (an external-language
compiler that produced the first stage 1) committed to this
distribution — that lineage exists upstream.

R13-D1 Phase 1 update (v0.8.280): the `bin/` directory contains
four other support artifacts (`nucleor_tools.exe`, `nucleor-lsp.exe`,
`nucleor_O2.exe`, `nucleor_s1_backup.exe`) — see `bin/README.md`
for per-artifact role and class. None of those are bootstrap-load-
bearing; only `bin/nucleor.exe` is the bootstrap chain's anchor.

The `nuc bootstrap` command reports the live state:

```
$ nuc bootstrap
=== Nucleor Bootstrap Status ===
  Stage: 1 (self-hosted)
  Examples: 18 (18 positive, 0 error)
  Runtime source: stdlib/runtime/nucleor_llvm_rt.c
  Runtime: 4945 lines, ~748 symbols
  Self-hosted: yes
  Contract: NUCLEOR_BOOTSTRAP_CONTRACT.md
```

## The fixed-point invariant (the load-bearing contract)

The verify gate's final step (`tools/verify.sh` / `tools/verify.ps1`)
rebuilds the compiler from source:

```
bin/nucleor.exe build compiler/nucleor_s1_compiler.nr -o verify_compiler
```

If this build does not succeed, the gate fails and the release does
not ship. This is the **self-host invariant** — every committed
`bin/nucleor.exe` must be capable of compiling its own source.

The historical chain pattern (used during v0.1 bootstrap and any
v0.2.x sub-chain release that touched the compiler) was the
2-iteration LLVM IR fixed-point check:

```bash
./bin/nucleor.exe build compiler/nucleor_s1_compiler.nr \
    -o bin/nucleor_vNNN.exe
./bin/nucleor_vNNN.exe build compiler/nucleor_s1_compiler.nr \
    -o bin/nucleor_v(NNN+1).exe
diff -q target/nucleor_vNNN.ll target/nucleor_v(NNN+1).ll
```

When `diff` reports the IR is byte-identical between the two
iterations, the compiler is at a fixed point — meaning the source
the new compiler emits matches what the previous compiler emitted,
which means the binary is stable under self-application.

The v0.2.x sub-chain through v0.2.121 has preserved the fixed
point on every promotion that touched compiler / runtime / s1
source. Most of the **v0.2.50–v0.2.121 sub-chain** has been
tooling-only — but two releases did make compiler source
changes:

- **v0.2.84** — added `doc` and `fix` entries to `print_usage`
  in `compiler/nucleor_s1_compiler.nr` so they appear in
  `nuc help` output.
- **v0.2.87** — added `-V`, `-v`, and bare `version` aliases
  alongside `--version` in the dispatch.

Both ran the standard 2-iteration LLVM IR fixed-point check
(see "Bootstrapping a fresh clone" below for the recipe) and
both produced byte-identical IR across iterations. The
self-host invariant therefore holds across every promotion
in the sub-chain. (The v0.2.79 fix to the explain registry in
`nucleor_tools_suite.nr` touches a *different* binary —
`bin/nucleor_tools.exe` — which is git-ignored and rebuilt
on every gate run since v0.2.79.)

## Two binaries, one source tree

| Binary | Source | Tracked in git? | Rebuilt by gate? |
|---|---|---|---|
| `bin/nucleor.exe` | `compiler/nucleor_s1_compiler.nr` | yes | yes (verify step) |
| `bin/nucleor_tools.exe` | `compiler/nucleor_tools_suite.nr` | no | yes (since v0.2.79) |

`bin/nucleor.exe` is the s1 compiler — it lexes, parses,
type-checks, generates LLVM IR, and dispatches CLI commands. The
explain / bootstrap / test-runner / etc. CLI subcommands are
handled by `bin/nucleor_tools.exe` (the tools-suite binary), which
the s1 compiler shells out to via `run_external_tool`. The drift
gate enforces ABI parity between the two source files (their
`get_rt_name` / `is_ptr_ret` / `is_ptr_arg` / `is_void_ret` tables
must agree).

## Runtime layer

The runtime is a single C source file:

```
stdlib/runtime/nucleor_llvm_rt.c
```

(4944 lines as of v0.2.131; the runtime hasn't gained new
helpers since v0.2.81 — only doc work has shipped). The
compiler emits LLVM IR that calls into these symbols via
`declare`-d externs; clang links the runtime archive at the
final link step. Auxiliary `_rt.c` files (string_rt.c,
hashmap_rt.c, btreemap_rt.c, vecdeque_rt.c, etc.) provide
collection and platform primitives.

Two different "symbol count" numbers appear in the toolchain;
both are correct, they answer different questions:

- **`nuc bootstrap status` reports `~748 symbols`** —
  `bootstrap_runtime_symbol_count()` (in
  `compiler/nucleor_tools_suite.nr`) line-counts every place
  in `nucleor_llvm_rt.c` that mentions `__nucleor_` followed
  by `(`, excluding comments. This conflates definitions,
  extern declarations, and internal call sites into one
  per-mention number.
- **The helper manifest catalogues 676 unique helpers** —
  `docs/rfcs/helper_manifest.toml` (Phase 2 contract, 95.1%
  populated as of v0.2.121) lists each `__nucleor_*` symbol
  exactly once across the s1 ABI tables + the entire runtime
  surface (main `_rt.c` + auxiliary `*_rt.c` files). This is
  the stable user-facing symbol count.

See `docs/rfcs/HELPER-CONTRACT.md` for the cataloging contract.

## Examples corpus

The verify gate builds and runs every example in `examples/`. As of
v0.2.121 this is 18 examples (`examples/01_hello.nr` through
`examples/18_benchmark.nr`), plus 4 build-only `examples/showcase/*.nr`
programs (`lorenz`, `vqe_h2`, `market_maker`, `wing_simulator`)
covered by the v0.2.90 `showcase_build_smoke` step. The numbered
list is maintained in `tools/examples.list` (single source of truth
shared between bash and PowerShell gates since v0.2.60).

Each example must compile via `nuc build`, link against the
runtime, and produce non-empty stdout when run. Empty stdout fails
the gate (added v0.2.61 / v0.2.62 — caught a regression where a
silently-no-print example would otherwise have shipped).

## Bootstrapping a fresh clone

```bash
# Linux/macOS
git clone https://github.com/APEXINTELORG/Nucleor.git
cd Nucleor
bash tools/verify.sh

# Windows
git clone https://github.com/APEXINTELORG/Nucleor.git
cd Nucleor
powershell -ExecutionPolicy Bypass -File tools\verify.ps1
```

The gate runs **204 steps as of v0.2.131**: binary present,
ABI parity, tools-suite rebuild, mojibake check, err-EXPECT-
headers (since v0.2.118), 14 CLI smoke steps (help-coverage,
utility, JSON, version, showcase build, explain single + full
161-code spec catalog, bootstrap, check+abi, inspectors,
diagnostics, init, doc, lock, test), every example (18),
every test in `tests/{lang,attrs,runtime,rods,features}`
(~140), every negative test in `tests/err` (33), and the
self-host rebuild at the end.

If the gate is green, the bootstrap is healthy. If it fails, the
diagnostic output names the failing step.

## Cross-platform status

As of v0.2.121 only Windows x86_64 has a committed bootstrap binary.
Linux / macOS bootstrap binaries land alongside the v0.3.0
cross-build work (see `docs/milestones/v0.3.0.md`). Until then, the
POSIX `./nuc` shell wrapper resolves clang and execs
`bin/nucleor.exe` under Wine on Linux/macOS hosts. The bash
`tools/verify.sh` runs on the Linux/macOS gate side under that
arrangement.

## What changes the contract

- **A new committed `bin/nucleor.exe`** must pass the self-host
  rebuild and (when the change touches compiler internals) preserve
  the LLVM IR fixed point. Changes to compiler source without a
  matching binary refresh are caught by the verify gate's final
  step.
- **A new `__nucleor_*` symbol** added to the s1 compiler (or to
  the runtime) MUST also be added to the tools-suite mirror tables
  — the drift gate (`tools/check_compiler_drift.sh`) blocks
  divergence.
- **A new helper** also requires a regenerated
  `helper_manifest.toml` in the same commit (since v0.2.41).
- **A new error code** added to
  `docs/spec/Nucleor_Error_Codes.md` requires entries in all
  three explain registry functions in
  `compiler/nucleor_tools_suite.nr` AND a new entry in the
  `cli_explain_full_smoke` list in both gate scripts (since
  v0.2.79 / v0.2.80).
