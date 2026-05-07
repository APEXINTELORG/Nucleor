# ML Suite NumPy parity rod batch — Queue ML-12

Agent: local ml-suite agent (v0845)
Date: 2026-05-07
Branch: fix/ml-12-batch-9-numpy-parity-rods-v0845

## Headline

Lands **10 of 14 NumPy parity rods** at 30-run stability. 4 deferred (broadcast_reduce_f32, elementwise_f32, reduce_axis_f64, transpose_reshape_f64).

## Ship-ready (10) — `tests/features/ml_numpy_*.nr`

| Rod | NumPy surface |
|---|---|
| `ml_numpy_broadcast_add_f64` | row broadcast add |
| `ml_numpy_csv_decimal_f64` | CSV decimal ingest into f64 tensor |
| `ml_numpy_csv_ingest_f64` | CSV integer ingest into f64 tensor |
| `ml_numpy_div_pow_f64` | divide + integer-power |
| `ml_numpy_dtype_policy` | dtype size + accumulator + policy assertions |
| `ml_numpy_elementwise_mul_f64` | elementwise multiply |
| `ml_numpy_matmul_f32` | f32 matmul (via i64 bit-pattern path) |
| `ml_numpy_matmul_f64` | f64 matmul |
| `ml_numpy_matvec_f64_f32` | f64 + f32 matrix-vector |
| `ml_numpy_slice_f64` | 2D slicing |

## Deferred (4)

| Rod | Symptom |
|---|---|
| `numpy_broadcast_reduce_f32` | f32 axis-reduction state UB |
| `numpy_elementwise_f32` | f32 multi-op composition UB |
| `numpy_reduce_axis_f64` | f64 axis-reduction intermittent |
| `numpy_transpose_reshape_f64` | composed shape-op UB |

## Build / drift

- 14/14 build clean.
- 10/10 stable across 30 runs.
- Drift gate clean.

End of finding.
