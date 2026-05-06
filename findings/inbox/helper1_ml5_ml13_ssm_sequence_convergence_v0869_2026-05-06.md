# Helper1 Finding - ML-5 / ML-13 SSM Sequence Convergence (v0869)

## Summary

ML-5 P1 and ML-13 P2b are now partially closed for the selective-scan SSM path:

- Added `ssm_selective_scan_backward(...)` in `ssm.nr`.
- Runtime backward returns five gradient handles: `[grad_x, grad_delta, grad_A, grad_B, grad_C]`.
- Added `tests/features/ssm_sequence_convergence_smoke.nr`.
- The fixture trains scalar per-step `B[t]` weights against a cumulative sequence target and asserts both material loss reduction and final sequence accuracy.

This is a real forward/backward/update convergence oracle for the Mamba-style selective scan, not just a link or non-null smoke.

## Evidence

Focused fixture:

- `tests/features/ssm_sequence_convergence_smoke.nr`

Validated commands:

```powershell
git diff --check -- stdlib/runtime/ssm_rt.c stdlib/rods/ssm.nr tests/features/ssm_sequence_convergence_smoke.nr
.\bin\nucleor.exe build tests\features\ssm_sequence_convergence_smoke.nr -o helper1_ssm_sequence_convergence --no-cache
.\target\helper1_ssm_sequence_convergence.exe
bash tools/verify.sh --only "test features/ssm_sequence_convergence_smoke"
bash tools/verify.sh --only "test features/ssm_smoke"
```

The fixture checks:

- Selective-scan forward produces trainable predictions.
- Selective-scan backward returns usable `grad_B`.
- Explicit parameter updates reduce loss below 1% of the initial loss.
- Final outputs match `[0.5, 1.0, 1.5, 2.0]` within tolerance.
- Existing `ssm_smoke` ZOH coverage still passes.

## Files Changed

- `stdlib/runtime/ssm_rt.c`
- `stdlib/rods/ssm.nr`
- `tests/features/ssm_sequence_convergence_smoke.nr`
- `docs/rfcs/gap-analyses/Nucleor_Tensor_ML_Autodiff_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/README.md`

## Residual

This covers the Mamba-style selective-scan backward path. SSD chunked, RWKV WKV, and xLSTM backward paths remain open. The new backward helper is also not yet wired into the global `autodiff.nr` tape; it is a direct rod/runtime gradient surface.

## Diagnostic Caveat

The compiler still emits stale overbroad `info[ML-G2-3-5-6-10]` text saying SSM rods have no backward paths. That diagnostic text now needs a compiler-side refresh; the stdlib/runtime surface and fixture exist on this branch.
