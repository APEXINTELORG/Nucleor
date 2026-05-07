# ML Suite recovery smokes round 22 — Queue ML-39

Branch: fix/ml-39-batch-36-recovery-round22-v0845
Date: 2026-05-07

## Headline

**3/3 stable**: scikit-learn binary classification metrics (precision/recall/F1), explicit recovery of tensor matmul, tensor matvec.

| | Count |
|---|---:|
| Candidates | 3 |
| Build clean | 3/3 |
| 30-run stable | **3/3** |

## Ship-ready (3)

| Smoke | Surface |
|---|---|
| `ml_recover_binary_metrics_f64` | scalar `binary_precision_i64` + `binary_recall_i64` + `binary_f1_i64` over y_true=[1,1,1,0,0], y_pred=[1,1,0,0,1] → all 2/3 |
| `ml_recover_tensor_matmul_2x2_f64` | tensor matmul 2x2 × 2x2: [[1,2],[3,4]] × [[5,6],[7,8]] = [[19,22],[43,50]] |
| `ml_recover_tensor_matvec_f64` | tensor matvec 2x3 × 3x1: A=[[1..6]], x=[10,20,30] → y=[140, 320] |

These three primitives are foundational — the binary metrics close out the sklearn classification metrics surface, while matmul/matvec are the tensor primitives most other parity rods build on.

## Cumulative recovery surface (after ML-18..39): 71 capabilities

End of finding.
