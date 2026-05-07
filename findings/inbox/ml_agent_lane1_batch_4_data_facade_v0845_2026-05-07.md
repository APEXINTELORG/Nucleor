# ML Suite data_facade integration — Queue ML-7

Agent: local ml-suite agent (v0845)
Date: 2026-05-07
Branch: fix/ml-7-batch-4-data-facade-v0845 (from origin/main HEAD)
Sandbox: `C:\Users\JoeWe\Desktop\Nucleor_AGENT_ml_suite_v0845`

## Headline

Lands `data_facade.nr` — the **last cross-cutting Tier-S core** identified in ML-2's ship-ready short list. Was deferred from ML-4 because the master `tests/data_core_smoke.nr` reads CSV fixtures that don't exist in the canonical repo. Replaced with a hand-authored, fixture-free smoke that exercises `frame_i64_f64_from_vec` + `frame_i64_f64_groupby_sum_mean` + `frame_i64_f64_filter_value_ge` + `frame_i64_f64_values_tensor`.

| | Detail |
|---|---|
| Rod added | `stdlib/rods/ml/data_facade.nr` (290 LOC, 20 fns) |
| Smoke added | `tests/features/ml_data_facade_smoke.nr` (76 LOC, hand-authored, fixture-free) |
| Manifest delta | 287 → 288 rods, +20 fns, +290 LOC |
| Drift gate | clean |
| Smoke run | 5/5 deterministic (`OK ml_data_facade_smoke`) |

## Smoke design

The hand-authored smoke validates the pandas-style frame surface against known-good outputs:

- 5-row frame with keys `[1, 1, 2, 2, 3]` and values `[10, 20, 30, 40, 50]`.
- `frame_i64_f64_values_tensor` projection produces a 5×1 TensorF64 with the value column.
- `frame_i64_f64_filter_value_ge(25.0)` keeps rows with value ≥ 25 → 3 rows starting at value 30.
- `frame_i64_f64_groupby_sum_mean` produces 3 groups: key 1 (sum 30, count 2), key 2 (sum 70, count 2), key 3 (sum 50, count 1). Verified via direct field access (`grouped.groups`, `grouped.keys`, `grouped.sums`, `grouped.counts`).

The smoke uses direct struct-field access on `GroupedI64F64` because the source rod doesn't expose tensor-conversion helpers for the grouped result — that's a Round-2 polish item.

## Round-3+ implication

`data_facade.nr` integration unblocks the ParallelAgent-tree pandas-deep parity rods batch (~75 rods covering cumsum/cumprod/cummax/cummin/diff/abs/clip/expanding/groupby variants). That batch is gated on the fixture relocation in ML-8.

## Residuals

- None blocking ML-7 promotion.
- Tools-side `tools/gen_rod_manifest.nr` subdir-recursion (from ML-4, already on main) handled the new rod transparently.

End of finding.
