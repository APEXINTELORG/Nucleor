# Local Claude3 QM6 MPS Streaming Range Integration v0842

Status: integrated locally for review before push.

## Branches

- Source branch: `origin/fix/local-claude3-qm6-mps-streaming-range-v0842`
- Integration branch: `integrate/postbatch-v0842`
- Integration commit before amend: `0a75adba qm6: bounded MPS streaming-range fold helpers`
- Base at integration time: `origin/main` after `0daec53a qm7: minimal OpenQASM 2.0 emit-only stdlib surface`

## Scope

This slice adds bounded MPS statevector range-fold helpers so callers can extract and fold a limited statevector window without requiring whole-state materialization.

Changed files:

- `stdlib/rods/mps.nr`
- `stdlib/runtime/mps_rt.c`
- `tests/features/mps_statevector_range_fold_smoke.nr`
- `docs/rfcs/v1_PUNCHLIST.md`

## Validation

Commands run from `C:\Users\JoeWe\Desktop\Nucleor_OSS_integrate_postbatch_v0842`:

```text
.\bin\nucleor.exe build tests\features\mps_statevector_range_fold_smoke.nr -o _mps_range_fold_v0842_integration --no-cache
.\target\_mps_range_fold_v0842_integration.exe
bash tools/check_rod_void_abi.sh
git diff --check HEAD~1..HEAD
```

Observed results:

- Feature build: PASS
- Feature executable: PASS, exit 0
- Rod ABI check: PASS
- Diff whitespace check: PASS

No compiler source changed in this slice, so no compiler promotion, self-host drift, or cold perf gate was required for this integration step.
