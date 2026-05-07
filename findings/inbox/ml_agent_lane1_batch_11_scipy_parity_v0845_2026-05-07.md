# ML Suite SciPy stats parity rod batch — Queue ML-14

Branch: fix/ml-14-batch-11-scipy-stats-parity-rods-v0845
Date: 2026-05-07

## Headline

Lands **5 of 6 SciPy parity rods** + applies the **6-LOC `print(<f64>)` typing fix** flagged in ML-3 §3 B.2 to `ml_scipy_stats_ttest_f64.nr`. 1 deferred (`ml_scipy_stats_normal_distribution_f64`).

## Ship-ready (5)

| Rod | SciPy surface |
|---|---|
| `ml_scipy_stats_describe_f64` | mean / variance / std / covariance / Pearson / z-score |
| `ml_scipy_stats_histogram_f64` | fixed-width histogram counts + bin edges |
| `ml_scipy_stats_quantile_f64` | sorted, q25, median, q75, IQR |
| `ml_scipy_stats_rank_extrema_f64` | min / max / range / argmin / argmax / rankdata(method="average") |
| `ml_scipy_stats_ttest_f64` | one-sample + Welch t-test (statistic + exact Student-t p-values) |

## ML-3 §3 B.2 fix applied

`ml_scipy_stats_ttest_f64.nr` had 6 occurrences of `print(<f64>)` that fail under canonical 0.8.323's TYP-006 ("argument 0 of 'print' must be str"). Renamed to `print_f64(<f64>)`. Single-file change, 6 LOC.

```diff
-    print(one.statistic);
+    print_f64(one.statistic);
-    print(one.pvalue_two_sided);
+    print_f64(one.pvalue_two_sided);
-    print(one.df);
+    print_f64(one.df);
-    print(welch.statistic);
+    print_f64(welch.statistic);
-    print(welch.pvalue_two_sided);
+    print_f64(welch.pvalue_two_sided);
-    print(welch.df);
+    print_f64(welch.df);
```

## Deferred (1)

| Rod | Symptom |
|---|---|
| `ml_scipy_stats_normal_distribution_f64` | normal PDF/CDF approximation kernel UB |

End of finding.
