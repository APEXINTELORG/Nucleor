# ML Suite ParallelAgent-tree pandas-deep parity rod batch — Queue ML-16

Branch: fix/ml-16-batch-13-pandas-pa-tree-v0845
Date: 2026-05-07

## Headline

Lands the **PA-tree data_facade.nr upgrade** (a strict superset of master's: +124 functions, 0 removed) plus **15 of 84 pandas-deep parity rods** at 30-run stability. 69 deferred — same latent UB pattern documented in ML-9..ML-15.

This batch is **structurally significant** because the data_facade upgrade unblocks all 84 pandas-deep parity rods at compile time (the 4 from master that are already on main + the 80 PA-tree-only). Without it, the PA tree's added 75+ pandas helpers (cumsum/cumprod/cummax/cummin/diff/abs/clip/expanding/groupby variants) are not callable from any integration.

## What changed

| Item | Detail |
|---|---|
| `stdlib/rods/ml/data_facade.nr` | replaced master version (20 fns) with PA superset (144 fns) |
| Manifest delta | 287 → 288 rods (data_facade is renamed-overwrite; +124 fns, +1948 LOC) |
| New parity rods at `tests/features/ml_pandas_*.nr` | 15 |
| Drift gate | clean |
| Pre-existing master `ml_data_facade_smoke` | re-tested — still `OK ml_data_facade_smoke`, all field surfaces work |

## Ship-ready (15) — `tests/features/ml_pandas_*.nr`

| Rod | pandas surface |
|---|---|
| `ml_pandas_cumsum_i64_f64` | `Series.cumsum()` |
| `ml_pandas_filter_value_eq_i64_f64` | `df[df["v"] == k]` |
| `ml_pandas_filter_value_ne_i64_f64` | `df[df["v"] != k]` |
| `ml_pandas_groupby_count_min_max_i64_f64` | `groupby().agg(["count","min","max"])` |
| `ml_pandas_groupby_i64_f64` | `read_csv().groupby().agg(["sum","mean"])` (master) |
| `ml_pandas_groupby_rank_max_i64_f64` | `groupby().rank(method="max")` |
| `ml_pandas_head_tail_i64_f64` | `head(n)`, `tail(n)` |
| `ml_pandas_multi_column_sort_describe_i64_f64` | `sort_values(by=cols).describe()` |
| `ml_pandas_sort_values_asc_i64_f64` | `sort_values(ascending=True)` |
| `ml_pandas_string_drop_duplicates_f64` | string-keyed `drop_duplicates()` |
| `ml_pandas_string_filter_project_f64` | string-keyed boolean filter + project |
| `ml_pandas_string_groupby_f64` | string-keyed groupby agg |
| `ml_pandas_string_sort_describe_f64` | string-keyed sort + describe |
| `ml_pandas_string_value_counts_f64` | string-keyed `value_counts()` |
| `ml_pandas_value_counts_i64_f64` | i64-keyed `value_counts()` |

## Deferred (69)

The deferred set covers the deeper window/cumulative/groupby family: `cummax`, `cummin`, `cumprod`, `expanding_*` variants, `groupby_*_*` cross products, `diff`, `abs`, `clip`, `between_filter`, `centered_value`, `pct_change`, `nlargest`/`nsmallest`, `sort_values_desc` and many string/category variants. Build-clean (84/84). Runtime-stable (15/84). Same latent UB class flagged across all parity batches.

Pattern observation: the 15 stable pandas rods are dominated by **single-pass ops over an inline-literal frame**. The 69 deferred include **multi-step state mutations** (cum* fns store a running accumulator; expanding fns walk an unbounded window; groupby cross products fold across keys). Consistent with the UB symptom across ML-9..ML-13.

## Files

```
M  stdlib/rods/ml/data_facade.nr     # replaced with PA superset (144 fns, +1948 LOC)
M  docs/rfcs/rod_manifest.toml       # regenerated
A  tests/features/ml_pandas_cumsum_i64_f64.nr
A  tests/features/ml_pandas_filter_value_eq_i64_f64.nr
A  tests/features/ml_pandas_filter_value_ne_i64_f64.nr
A  tests/features/ml_pandas_groupby_count_min_max_i64_f64.nr
A  tests/features/ml_pandas_groupby_i64_f64.nr
A  tests/features/ml_pandas_groupby_rank_max_i64_f64.nr
A  tests/features/ml_pandas_head_tail_i64_f64.nr
A  tests/features/ml_pandas_multi_column_sort_describe_i64_f64.nr
A  tests/features/ml_pandas_sort_values_asc_i64_f64.nr
A  tests/features/ml_pandas_string_drop_duplicates_f64.nr
A  tests/features/ml_pandas_string_filter_project_f64.nr
A  tests/features/ml_pandas_string_groupby_f64.nr
A  tests/features/ml_pandas_string_sort_describe_f64.nr
A  tests/features/ml_pandas_string_value_counts_f64.nr
A  tests/features/ml_pandas_value_counts_i64_f64.nr
A  findings/inbox/ml_agent_lane1_batch_13_pandas_pa_tree_v0845_2026-05-07.md
```

End of finding.
