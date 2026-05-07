# ML Suite recovery smokes round 4 — Queue ML-21

Branch: fix/ml-21-batch-18-recovery-round4-v0845
Date: 2026-05-07

## Headline

**2 more deferred capabilities recovered**: `last_row_f64` (final-hidden-row extraction for LM head decode plumbing) and `categorical_sample_i64` (deterministic sampling from probabilities given explicit thresholds — useful for repro-friendly generation). 1 attempted recovery (`kv_cache_append`) fails — tensor concatenation has the multi-step state UB.

| | Count |
|---|---:|
| Candidates | 3 |
| Build clean | 3/3 |
| 30-run stable | **2/3** |

## Ship-ready (2)

| Smoke | Test approach |
|---|---|
| `ml_recover_last_row_f64` | (3, 4) hidden tensor: `last_row` returns row 2 = [9, 10, 11, 12]. Verifies shape and exact values. |
| `ml_recover_categorical_sample_f64` | Probabilities [0.5, 0.3, 0.2] → cumulative [0.5, 0.8, 1.0]; thresholds 0.4/0.7/0.95 → buckets 0/1/2. |

## Failed

| Smoke | Why |
|---|---|
| `ml_recover_kv_cache_append` | Concatenates two tensors row-wise — same multi-step state UB as `ml_torch_kv_cache_append_attention_f64` (deferred ML-11). Tensor concat path triggers UB regardless of size. |

## Cumulative recovery surface (after ML-18+19+20+21): 13 capabilities

The recovery pattern continues to deliver: 13 of the originally-deferred parity capabilities now have stable, hand-authored production-quality smokes that pass 30/30 deterministic runs without needing the upstream Nucleor language fix.

End of finding.
