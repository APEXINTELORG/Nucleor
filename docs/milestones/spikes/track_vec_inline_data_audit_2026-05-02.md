# Track Vec Inline-Data Audit - 2026-05-02

Branch: `spike/v06-vec-inline-data-audit`
Initial base: `origin/main` `091ce77` (`v0.6.6`)
Final base after rebase: `origin/main` `f6231c9` (`v0.6.8`)

## Scope

This spike investigated the lane-B report from
`Desktop/Nucleor_PARALLEL_1_BRIEF_2026-05-01.md`: one observed flaky stage1
self-host `OWN-008` at `priv_mangle_private_fns` after the v0.5.32
`NVec.inline_data[2]` small-buffer change. The suspected class was a remaining
runtime path that kept stale pointers across inline-to-heap migration or freed
inline storage as if it were heap storage.

## Audit Result

The original stage1 `OWN-008` did not reproduce on current `origin/main` in 10
pre-patch capped stage1 self-host builds. All 10 passed.

Two concrete inline-data hazards were found and patched:

1. `__nucleor_vec_extend(dst, src)` used `src->len` as a live loop bound while
   pushing into `dst`. For `vec_extend(v, v)`, the loop could grow the source
   while iterating it and cross inline-to-heap migration during the read.
2. `stdlib/runtime/mem_rt.c` still declared the old three-field `NVec` layout
   and unconditionally freed `v->data`. That is invalid when `v->data` points
   at `v->inline_data`.

## Patch

- `stdlib/runtime/nucleor_llvm_rt.c`
  - `__nucleor_vec_extend` now snapshots the original source length.
  - Each element is read into a local value before the push, so self-aliasing
    cannot read through storage that may migrate during the push.
- `stdlib/runtime/mem_rt.c`
  - Local `NVec` layout now matches `nucleor_llvm_rt.c`, including
    `inline_data[2]`.
  - `nuc_vec_free` skips freeing inline storage.
  - `nuc_vec_mem_bytes` reports only the struct size while the Vec is inline.
- `tests/features/vec_extend_self_inline.nr`
  - Locks `vec_extend(v, v)` on a 2-cell inline Vec.
- `tests/rods/mem_inline_free.nr`
  - Calls `nuc_vec_free` directly on an inline-backed Vec to exercise
    `mem_rt.c`.
- `tools/verify.sh`
  - Adds `NVec inline runtime ownership regressions` as a focused verify step.

## Validation

Focused verify step under the real-time peak-memory wrapper:

```text
bash tools/verify.sh --only "NVec inline runtime ownership regressions"
PASS: step 4.60s
wrapper peak: 245 MB
wall: 96.41s
killed: False
```

Post-patch stage1 self-host loop, capped with
`tools/measure_peak_build.ps1 -BudgetMb 770 -WarningMb 650 -SampleMs 100`:

```text
run 01: PASS peak 676 MB, wall 7.028s
run 02: PASS peak 677 MB, wall 5.565s
run 03: PASS peak 677 MB, wall 7.862s
run 04: PASS peak 676 MB, wall 6.897s
run 05: PASS peak 677 MB, wall 8.650s
run 06: PASS peak 670 MB, wall 6.634s
run 07: PASS peak 678 MB, wall 7.702s
run 08: PASS peak 643 MB, wall 6.909s
run 09: PASS peak 675 MB, wall 6.656s
run 10: PASS peak 678 MB, wall 9.957s
```

Result: 10/10 consecutive stage1 self-host builds passed. Max observed peak was
`678 MB`, below the `770 MB` tight gate and below the `1 GB` emergency stop.
This is not the long-term memory target; it is only this spike's safety
evidence.

After rebasing onto `origin/main` `f6231c9`, the focused ownership smoke was
rerun and passed again:

```text
PASS: step 5.04s
wrapper peak: 180 MB
wall: 107.75s
killed: False
```

## Remaining Risk

Because the original `OWN-008` did not reproduce before the patch, this is a
hazard fix plus regression coverage rather than proof that the exact observed
flake was the same root cause. If `OWN-008` appears again, the next
discriminator should log the owning symbol and runtime Vec operations around
`priv_mangle_private_fns`.
