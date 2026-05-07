# DFLIP-VALIDATE follow-up — fix ownership and handoff plan

## TL;DR

The 80 ML fixture failures on Linux post default-flip are a **compiler
fix**, not a stdlib fix. The bug is in `auto_drop_mark_constructor_handoffs`
(the IR-analysis pass shipped at commit `e5081625` in
`compiler/nucleor_s1_compiler.nr`), and the most efficient path is:

1. **Integrator / ML agent (local Windows)** writes the s1 patch.
2. **Cloud (Linux)** validates on each iteration.

This split is right because the bug *reproduces* on Linux but *doesn't*
on Windows (heap-allocator pattern luck), and the *fix authorship*
requires design context for the pass the integrator just shipped.

## Why local is the right shipper, not cloud

| Factor | Local (integrator/ML agent) | Cloud (me) |
| --- | --- | --- |
| Owns design intent for `auto_drop_mark_constructor_handoffs` | ✅ shipped `e5081625` | ❌ would have to reverse-engineer |
| Reproduces the bug deterministically | ❌ Windows masks via MSVC heap pattern | ✅ Linux glibc surfaces it every run |
| Iteration speed on the patch itself | ✅ fast (no bootstrap-and-verify cycle for ideation) | ⚠️ ~35 min per iteration |
| Validates the patch with byte-level evidence | ❌ host masks regressions | ✅ same DFLIP-VALIDATE pipeline |

The cleanest workflow:

```
[local writes s1 patch on fix/default-flip-experiment-v0846]
       │
       ▼
[push to origin, ping cloud]
       │
       ▼
[cloud rebases, rebootstraps, runs verify.sh + verify_strict.sh]
       │
       ├── md5 still 603891a9ec0a46fc1c6e41a2854317ce? → IR parity preserved
       ├── default + strict FAIL count drops? → patch is closing cases
       └── all 80 fixtures green? → ready to fast-forward to main
```

## The bug, restated mechanically

`compiler/nucleor_s1_compiler.nr:29944` was default-flipped in `e5081625`
so auto-drop now fires unless `#[manual_drop]` opts out. The pass
`auto_drop_mark_constructor_handoffs` is supposed to recognize call
shapes where a `Vec<T>` is moved into a struct field that is then
returned — and skip auto-drop on the original `Vec` because ownership
has been handed off.

The pass currently recognizes the **leaf constructor pattern**:

```nucleor
fn tensor_f64_from_vec(rows: i64, cols: i64, data: Vec<f64>) -> TensorF64 {
    return TensorF64 { ..., data: data };  // ← handoff recognized
}
```

It currently MISSES the **wrapper pattern**:

```nucleor
fn nn_gelu_tanh_f64(input: &TensorF64) -> TensorF64 {
    let mut data: Vec<f64> = Vec::new();   // local Vec
    let mut i: i64 = 0;
    while i < tensor_f64_len(input) {
        data.push(nn_gelu_tanh_scalar_f64(input.data[i]));
        i = i + 1;
    };
    return tensor_f64_from_vec(input.shape.rows, input.shape.cols, data);
    // ↑ handoff NOT recognized — auto-drop fires on `data` after the
    //   call returns, freeing the heap memory the caller is about to
    //   read through the returned TensorF64.data field.
}
```

On Windows MSVC, the freed memory's first 4 bytes happen to look like
a small valid `len`. On Linux glibc, those same bytes are arbitrary —
e.g. `0xCAFE2773` sign-extends to `-893742413` and the runtime panics
with `index out of bounds: the len is -893742413`.

## What the patch likely needs to do

Extend `auto_drop_mark_constructor_handoffs` so that when a fn body's
return expression is a function call whose return type contains a `Vec<T>`
field, **any local Vec passed through that call's argument chain into the
field that ends up in the return** is marked as handed-off. Tracing rule:

- If `return CALL(args)` and `CALL` has return type with a `Vec<T>` field,
- and `args` includes a local `Vec<T>` `v` passed by value,
- and the analysis can show `v` ends up in the returned struct's `Vec<T>` field,
- then mark `v` as handed-off (skip auto-drop).

This is a transitive-handoff inference, similar in shape to existing
`#[manual_drop]` propagation but auto-discovered through the
constructor call chain.

## Minimal repro for the integrator to drive against

Pick **`ml_recover_sigmoid_f64`** from the common-23 list. Why this one:
- Fails in both default-mode and strict-mode runs (most stable repro)
- Likely a single wrapper fn → leaf constructor chain
- Small fixture, fast iteration

```bash
# On the integrator's Linux env (or via cloud) :
git checkout fix/default-flip-experiment-v0846  # bf097e07
bash tools/bootstrap_linux.sh
rm -f target/_pv_features_ml_recover_sigmoid_f64
bin/nucleor build tests/features/ml_recover_sigmoid_f64.nr -o _pv_features_ml_recover_sigmoid_f64 --no-cache
target/_pv_features_ml_recover_sigmoid_f64
# Expected today: PANIC: index out of bounds: the len is <NEGATIVE> ...
# Expected post-fix: real numeric output, RC=0
```

Trace the wrapper fn (likely `recover_sigmoid_f64` in `learn_facade.nr`
or a sibling) through `auto_drop_mark_constructor_handoffs`. Identify
the missing recognition rule. Patch s1. Repeat against the next fixture
in the common-23 list to confirm the rule generalizes.

## Validation loop (cloud's part)

Once the integrator pushes a candidate s1 patch on the experiment
branch:

1. Cloud receives the loop tick / message
2. `git fetch origin && git rebase origin/fix/default-flip-experiment-v0846`
3. `bash tools/bootstrap_linux.sh` — confirm md5 still matches
   `603891a9ec0a46fc1c6e41a2854317ce` (or report a new stamp if the
   patch shifts the IR fixed-point)
4. `bin/nucleor build compiler/nucleor_tools_suite.nr -o nucleor_tools && cp ...`
5. `NUC_VERIFY_PROBE=1 bash tools/verify.sh > /tmp/v_default.log`
6. `bash tools/verify_strict.sh > /tmp/v_strict.log`
7. Report PASS/SKIP/FAIL counts + per-fixture diff vs the prior 80-list
8. If FAIL=0 in both modes, signal "ready to fast-forward"
9. If non-zero, name the surviving fixtures (regression bucket) so the
   integrator knows whether the rule needs a second-order extension

Wall time per iteration: ~35 min (5 min bootstrap + 10 min default verify
+ 15 min strict verify + 5 min report).

## Alternative if you want cloud to attempt the s1 fix

If you'd rather I attempt the patch from cloud directly, authorize:
- "Cloud-DFLIP-PATCH" charter — explicit *patch* scope (current
  DFLIP-VALIDATE charter is "validation only, no patches")
- Time budget: I'd estimate 3-6 iterations to hypothesize and refine
  the recognition rule (12-36 min compiler-edit time + 35 min/iter
  validation)

I can do this — but the integrator is faster by virtue of having the
design context. My estimate: integrator-side fix lands in 1-2 iterations;
cloud-side fix takes 3-6.

## Files

- `findings/inbox/cloud_claude_dflip_validate_bf097e07_2026-05-07.md`
  (the original NOT-CLEAN audit with the 80-fixture list and verify
  transcripts)
- `findings/inbox/cloud_claude_dflip_handoff_plan_v0846_2026-05-07.md`
  (this writeup)

Branch: harness-pinned `claude/verify-round-3-tests-RnTlO`.
