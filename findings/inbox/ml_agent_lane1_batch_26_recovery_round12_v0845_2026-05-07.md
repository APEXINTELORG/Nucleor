# ML Suite recovery smokes round 12 — Queue ML-29

Branch: fix/ml-29-batch-26-recovery-round12-v0845
Date: 2026-05-07

## Headline

**3/3 stable**, with an important diagnostic refinement: `ai_concat_rows_f64` (standalone tensor row concatenation) recovers cleanly — but `ai_kv_cache_append_f64` (which calls concat twice, once for K and once for V) failed in ML-21. **Single concat is fine; double concat trips UB.**

| | Count |
|---|---:|
| Candidates | 3 |
| Build clean | 3/3 |
| 30-run stable | **3/3** |

## Ship-ready (3)

| Smoke | Surface |
|---|---|
| `ml_recover_concat_rows_f64` | `ai_concat_rows_f64` — (1×3) ++ (1×3) → (2×3) with exact value preservation |
| `ml_recover_stats_covariance_f64` | `stats_pearsonr_f64` (=1.0) and `stats_covariance_f64(ddof=1)` (5.0 in [4, 6]) for y = 2x + 1 |
| `ml_recover_stats_rankdata_f64` | scipy `rankdata(method="average")` over [3, 1, 4, 1, 5] → [3, 1.5, 4, 1.5, 5] |

## Refined diagnostic

The single-vs-double concat split is consistent with the broader pattern:

- Single forward pass → recovers
- **Repeated invocation of the same primitive within a struct return** → trips UB

This applies to:
- `ai_kv_cache_append_f64` calling concat for K and V (KvCacheF64 return)
- `nn_layer_norm_backward_f64` returning grad_input + grad_weight + grad_bias — but this DID recover in ML-27, so structured-multi-tensor return doesn't always trip; the trigger is more likely **the second call mutating tracker state from the first**.

The KV-cache failure mode specifically: concat(cache_k, next_k) then concat(cache_v, next_v) both produce TensorF64s that get packed into a single struct. The struct-pack step apparently doesn't handle the second return cleanly under the move/borrow tracker.

## Cumulative recovery surface (after ML-18..29): 43 capabilities

End of finding.
