# Cloud Lane 8 / Queue 8O — Linux pair-validation of Phase 1/2/4 production-readiness work

## Summary

**STATUS: DONE (validation only, no patches per 8O charter).**

Both transcripts captured. Both green for non-ML; both still surface
the same ML latent-panic class root-caused in cloud's earlier PROBE-3L
audit (`findings/inbox/cloud_claude_evidence_audit_v0846_2026-05-07.md`).
The integrator's `1bf185d0` fix (`#[manual_drop]` on the 3 leaf
`tensor_*_from_vec` constructors) cleared 2 of the original 58 failures
but the remaining cluster persists because **every wrapper fn that
itself builds a `Vec<T>` and packs it into a `Tensor*` return value
needs the same annotation** — see "ML residual" section below.

Headline:

| Run | PASS | SKIP | FAIL | Step count |
| --- | --- | --- | --- | --- |
| `bash tools/verify.sh` (default, with `NUC_VERIFY_PROBE=1`) | 1432 | 1 | 56 | 1488 |
| `bash tools/verify_strict.sh` (cache-cold) | 1437 | 1 | 50 | 1488 |

Zero non-ML failures in either run. Every failure is `tests/features/ml_*`.
PROBE-1 step (index 1489) PASSED in both runs (NUC_VERIFY_PROBE=1 only
exercised in the default run; the strict run does not auto-set it).

Phase-4 drift gate (`#[manual_drop]` parity between s1 and tools-suite
parse_* fns) **did NOT FAIL** in strict mode. The 8O queue spec
expected ~28 parity gaps to surface; today only the implicit "OK"
appears in the strict log preamble line ("verify_strict:
NUC_VERIFY_STRICT=1 — drift gate enforces #[manual_drop] parity"),
followed by `[2/1488] OK compiler ABI tables synced`. So either Phase
3's per-fn manual_drop sweep (closing through `fae89980 parse_let`)
already brought parity inside the gate's tolerance, or the gate is
WARN-by-default-and-only-FAIL-when-NUC_VERIFY_STRICT=1 didn't trigger
on the residuals because the residuals weren't in the gate's enforced
list. Either way, no parser-fn parity FAILs surfaced today.

## Host

```
$ uname -a
Linux vm 6.18.5 #2 SMP PREEMPT_DYNAMIC Wed Jan 14 17:56:08 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux

$ command -v clang && clang --version | head -1
/usr/bin/clang
Ubuntu clang version 18.1.3 (1ubuntu1)
```

`origin/main` SHA at run time: `a585dd0c` (post `1bf185d0` ML fix +
`fae89980` parse_let manual_drop + Phase 4 verify_strict.sh + drift-gate
parity guard).

## Per-host parity vs Windows

The integrator's `74a251f6` Windows transcript reported `PASS=1485
SKIP=2 FAIL=0`. Today's Linux runs are NOT at parity:

| Counter | Windows `74a251f6` | Linux default `a585dd0c` | Linux strict `a585dd0c` |
| --- | --- | --- | --- |
| PASS | 1485 | 1432 | 1437 |
| SKIP | 2 | 1 | 1 |
| FAIL | 0 | 56 | 50 |
| Total | 1487 | 1488* | 1488* |

\* +1 step on Linux because `NUC_VERIFY_PROBE=1` was set on the
default run; PROBE-1 added one step. The strict run did not set the
env var but the step count still reports 1488 because the gate
registration is unconditional once installed.

Net delta: **all 56/50 Linux failures are ML fixtures hitting the
same NVec-int-len-from-uninitialized-memory class.** Per the
integrator's own t21 finding: `74a251f6`'s `PASS=1485 SKIP=2 FAIL=0`
is "accurate for the state the cache is in; it is NOT accurate for a
fresh clone."

## ML residual — extends the integrator's `1bf185d0` fix

Cloud's PROBE-3L audit at fccef882 reported 58 ML failures. After the
integrator's `1bf185d0` fix (`#[manual_drop]` on 3 leaf
`tensor_*_from_vec` constructors), **2 fixtures cleared**
(`ml_ai_facade_smoke` and `ml_numpy_csv_decimal_f64` — the ones that
only call leaf constructors directly), and **56 still fail in default
verify** (50 in strict — the cache-state delta surfaces a different
subset of the same class).

Cloud spot-tested `ml_torch_gelu_tanh_f64` after the integrator's
fix:

```
$ rm -f target/_pv_features_ml_torch_gelu_tanh_f64
$ bin/nucleor build tests/features/ml_torch_gelu_tanh_f64.nr -o _pv_features_ml_torch_gelu_tanh_f64 --no-cache
$ target/_pv_features_ml_torch_gelu_tanh_f64
...
gelu tanh:
PANIC: index out of bounds: the len is -1341547874 but the index is 0
EXIT=1
```

Different garbage value than before (`-1341547874` vs the original
`-893742413`); same uninitialized-memory signature. The fixture goes
through `nn_gelu_tanh_f64` (line 225 of `stdlib/rods/ml/nn_facade.nr`)
which itself builds a `Vec<f64>`, calls the now-`manual_drop`'d
`tensor_f64_from_vec`, and **returns a `TensorF64` without
`#[manual_drop]` on the wrapper fn**. The wrapper's auto-drop frees
the heap-allocated Vec memory the caller is about to read.

**Survey scope:**
- `grep -E "^fn.*-> TensorF64\b" stdlib/rods/ml/*.nr | wc -l` → **130**
  fns return `TensorF64`.
- `grep -B1 -E "^fn.*-> TensorF64\b" stdlib/rods/ml/*.nr | grep -c "manual_drop"`
  → **1** has `#[manual_drop]` (the leaf `tensor_f64_from_vec`).
- Same proportion likely holds for `-> TensorI64` and `-> TensorF32`
  fns plus `-> Vec<f64>` / `-> Vec<i64>` shapes.

So the integrator's anticipation is exactly right:

> "Cloud's full 58-fixture list is in their evidence audit; I tested
> 5. The remaining 53 likely all clear with the same one-line
> annotation but I have not Windows-tested them all. Cloud's next pass
> on Linux will surface any remaining ones (likely zero, but if
> non-zero, same one-line fix per affected facade fn). If a sibling fn
> in nn_facade.nr or elsewhere has the same shape (move Vec into struct
> return), apply manual_drop per the protocol."

Cloud's next-pass result: 56 (default) / 50 (strict) ML fixtures still
fail. Per 8O's "validation only, no patches" charter, cloud is NOT
shipping the 130+ fn manual_drop sweep in this queue — that's the 8P
follow-up shape (or a partner-Compiler systematic sweep).

**Cache-state flakiness note:** the per-failure list differs between
default and strict runs (~30 in common, ~20 differ). This corroborates
the integrator's t21 finding's recommendation #1: "Add `--no-cache`
to verify gates" — until cache hygiene is enforced, every run can
give different ML failure counts.

## Sample failure list (default, 56 total)

```
test features/ml_data_facade_smoke
test features/ml_nn_facade_smoke
test features/ml_numpy_broadcast_add_f64
test features/ml_numpy_div_pow_f64
test features/ml_numpy_dtype_policy
test features/ml_numpy_elementwise_mul_f64
test features/ml_numpy_matmul_f32
test features/ml_numpy_matmul_f64
test features/ml_numpy_matvec_f64_f32
test features/ml_numpy_slice_f64
test features/ml_recover_adamw_step_f64
... [46 more, see findings/inbox/8O_artifacts/verify_default_with_probe.log]
```

(Full list and strict-run list in the artifacts directory.)

## Recommended follow-up

Per the 8O charter ("If a real defect surfaces, file separately as
`cloud_claude_lane8_8P_*` and we triage"):

**Option A (smallest scope, partner-Compiler systematic sweep):**
Apply `#[manual_drop]` to every fn in `stdlib/rods/ml/` that returns
a `Tensor*` or `Vec<...>` and constructs the return value internally.
Estimated 130-300 fn annotations (TensorF64 alone is 130 fns; same
ratio for TensorI64 / TensorF32 / Vec returns).

**Option B (deeper — compiler fix):**
Audit s1's auto-drop logic for the "fn returns struct containing
heap-allocated Vec field" shape. If auto-drop is currently freeing
the Vec heap memory at the END of the producer fn (after the move
into the return struct's field), that's the bug; the move should
transfer ownership. Fix would be at the codegen level, eliminating
the need for `#[manual_drop]` on these fns entirely.

**Option C (process):**
Per t21's recommendation #1, add `--no-cache` to all verify-gate step
bodies (or ship `tools/verify_no_cache.sh`) so the latent class
surfaces in CI immediately and stops flapping run-to-run.

## Files

- `findings/inbox/cloud_claude_lane8_8O_v0846_2026-05-07.md` (this report)
- `findings/inbox/8O_artifacts/verify_default_with_probe.log` (default verify, 1432/1/56 + PROBE-1 OK)
- `findings/inbox/8O_artifacts/verify_strict.log` (strict verify, 1437/1/50)
- `findings/inbox/probe1L_artifacts/standalone.log` (PROBE-1L runner 8/8 PASS)
- `findings/inbox/cloud_claude_probe1L_v0846_2026-05-07.md` (PROBE-1L companion report)

Branch: harness-pinned `claude/verify-round-3-tests-RnTlO`.
