# Track G Artifact: RFC-0007 Atomics Full Ship

Branch: `v05-track-g-atomics`
Scope: Round 2 Track G, RFC-0007 atomics.
Base requested by handoff: `origin/main` at `3e7cb0d`.

## Summary

RFC-0007 atomics are shipped on the Track G branch with a typed stdlib surface, compiler diagnostics, LLVM atomic lowering, feature fixtures, negative fixtures, and verify-gate coverage.

Implemented stdlib surface:

- Atomic shapes: `AtomicI64`, `AtomicU64`, `AtomicI32`, `AtomicU32`, `AtomicBool`.
- Ordering surface: `MemOrder::{Relaxed, Acquire, Release, AcqRel, SeqCst}`.
- Required `AtomicI64` operations: `atomic_load`, `atomic_store`, `atomic_compare_exchange`, `atomic_fetch_add`, `atomic_fetch_sub`, `atomic_fetch_and`, `atomic_fetch_or`, `atomic_fetch_xor`.

Implemented LLVM lowering:

- `load atomic i64, ptr ... <ordering>, align 8`
- `store atomic i64 ..., ptr ... <ordering>, align 8`
- `cmpxchg ptr ... <success-order> <failure-order>`
- `atomicrmw add/sub/and/or/xor ptr ... <ordering>`

Diagnostic wiring:

- `ATOMIC-001`: blocking call in `#[atomic]` function.
- `ATOMIC-002`: allocation in `#[atomic]` function.
- `ATOMIC-003`: `Cell` or `RefCell` used in `#[atomic]` function.
- `ATOMIC-004`: invalid `compare_exchange` success/failure ordering pair.
- `ATOMIC-005`: invalid load/store ordering literal.

## Files

Primary implementation:

- `compiler/nucleor_s1_compiler.nr`
- `compiler/nucleor_tools_suite.nr`
- `stdlib/rods/atomic.nr`
- `tools/verify.sh`
- `tools/verify.ps1`

Docs and drift mirrors:

- `docs/rfcs/RFC-0007-atomic.md`
- `docs/spec/Nucleor_Error_Codes.md`
- `docs/rfcs/helper_manifest.toml`
- `docs/rfcs/rod_manifest.toml`
- `RELEASES.md`
- `bootstrap/nucleor_s1_seed.ll`

Fixtures:

- `tests/features/rfc0007_atomic_basic.nr`
- `tests/features/rfc0007_atomic_orderings.nr`
- `tests/err/err_atomic_001_blocking.nr`
- `tests/err/err_atomic_002_alloc.nr`
- `tests/err/err_atomic_003_cell.nr`
- `tests/err/err_atomic_004_cmpxchg_order.nr`
- `tests/err/err_atomic_005_invalid_load_order.nr`

## Validation

All memory-sensitive compiler and tools-suite builds stayed under the required 1024 MB cap.

Self compiler build:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\measure_peak_build.ps1 -Source compiler\nucleor_s1_compiler.nr -OutName nuc_s1_track_g -BudgetMb 1024 -TimeoutSec 180
```

Result:

```text
OK: compiler\nucleor_s1_compiler.nr -> target\nuc_s1_track_g.exe, peak 486 MB / 1024 MB
```

Tools-suite mirror build:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\measure_peak_build.ps1 -Source compiler\nucleor_tools_suite.nr -OutName nucleor_tools -BudgetMb 1024 -TimeoutSec 180
```

Result:

```text
OK: compiler\nucleor_tools_suite.nr -> target\nucleor_tools.exe, peak 499 MB / 1024 MB
```

Two-stage fixed point:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\measure_peak_build.ps1 -Source compiler\nucleor_s1_compiler.nr -OutName stage_g_l -BudgetMb 1024 -TimeoutSec 180 -Bin bin\nucleor.exe
powershell -NoProfile -ExecutionPolicy Bypass -File tools\measure_peak_build.ps1 -Source compiler\nucleor_s1_compiler.nr -OutName stage_g_m -BudgetMb 1024 -TimeoutSec 180 -Bin target\stage_g_l.exe
```

Result:

```text
stage_g_l peak 820 MB / 1024 MB, wall 6.451s
stage_g_m peak 477 MB / 1024 MB, wall 4.533s
stage_g_l.ll == stage_g_m.ll
SHA256: C725C34D70F0143B5F01E0A4E771B99B339F6E789FAFA5BD919A7DB76F803A31
```

NUM-024 audit:

```powershell
$env:NUCLEOR_AUDIT_NUM024='1'
bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _audit_compiler --no-cache
bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o _audit_tools --no-cache
```

Result:

```text
NUM-024 compiler=0 tools-suite=0
```

Atomic fixture smoke:

```powershell
bin\nucleor.exe build tests\features\rfc0007_atomic_basic.nr -o _atomic_basic --no-cache
target\_atomic_basic.exe
bin\nucleor.exe build tests\features\rfc0007_atomic_orderings.nr -o _atomic_orderings --no-cache
target\_atomic_orderings.exe
```

Result:

```text
OK rfc0007_atomic_basic
OK rfc0007_atomic_orderings
LLVM IR contains load atomic, store atomic, cmpxchg, and atomicrmw add/sub/and/or/xor.
```

Negative diagnostic fixtures:

```text
err_atomic_001_blocking.nr -> error[ATOMIC-001]
err_atomic_002_alloc.nr -> error[ATOMIC-002]
err_atomic_003_cell.nr -> error[ATOMIC-003]
err_atomic_004_cmpxchg_order.nr -> error[ATOMIC-004]
err_atomic_005_invalid_load_order.nr -> error[ATOMIC-005]
```

Compiler drift, manifests, and release ledger:

```bash
./tools/check_compiler_drift.sh
```

Result:

```text
OK: tools-suite ABI tables match compiler/nucleor_s1_compiler.nr
OK: helper_manifest.toml is up to date
OK: rod_manifest.toml is up to date
OK: RELEASES.md is up to date
```

Mojibake audit:

```bash
./tools/check_mojibake.sh
```

Result:

```text
OK: no mojibake byte sequences detected
```

Full verify, env-off:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc "export NUCLEOR_MEM_CAP_KB=1048576; export NUCLEOR_INT_STRICT_INTRIN=0; ./tools/verify.sh --no-color"
```

Result:

```text
PASS: 622
SKIP: 1
self-host memory budget: peak 538 MB / 550 MB
tools-suite memory budget: peak 434 MB / 500 MB
RFC-0007 atomics lower to LLVM atomic IR: OK
```

Full verify, env-on:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc "export NUCLEOR_MEM_CAP_KB=1048576; unset NUCLEOR_INT_STRICT_INTRIN; ./tools/verify.sh --no-color"
```

Result:

```text
PASS: 622
SKIP: 1
self-host memory budget: peak 515 MB / 550 MB
tools-suite memory budget: peak 421 MB / 500 MB
RFC-0007 atomics lower to LLVM atomic IR: OK
```

## Notes

- The Track G branch was kept isolated. No edits were made in the main worktree and no push to `origin/main` is part of this lane.
- `AtomicU64`, `AtomicI32`, `AtomicU32`, and `AtomicBool` are first-class shape declarations with constructors and drop helpers. The full required operation surface is shipped for `AtomicI64`, matching the current compiler lowering architecture for concrete i64 atomic IR.
- `examples/showcase/vqe_h2.nr` had two existing mojibake comment bytes repaired so the repository-wide mojibake gate could pass.
- No unresolved Track G blocker remains in this branch.
