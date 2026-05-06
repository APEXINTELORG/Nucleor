# Helper1 C-17 Atomic Width Wrappers Closure

Date: 2026-05-06
Branch: `fix/helper1-quantum-robotics-residuals-v0835`
Scope: C-17 typed ordered atomic wrappers

## Summary

C-17 is closed for the raw-handle escape-hatch class. `AtomicU64`,
`AtomicI32`, and `AtomicU32` now expose typed ordered load/store/fetch/swap/CAS
wrappers in `stdlib/rods/atomic.nr`, matching the existing `AtomicI64` and
`AtomicBool` pattern.

The implementation deliberately reuses the existing i64 atomic storage cell and
LLVM i64 atomic lowering. It does not add a new native narrow-width allocation
ABI. That boundary is now stated in `atomic_limitations()` and the concurrency
gap analysis.

## Files

- `stdlib/rods/atomic.nr`
- `tests/features/rfc0007_atomic_width_wrappers.nr`
- `tests/features/concurrency_disclosure_smoke.nr`
- `docs/rfcs/v1_PUNCHLIST.md`
- `docs/rfcs/gap-analyses/Nucleor_Concurrency_Gap_Analysis_and_RFC_2026-05-04.md`

## Validation

Completed before integration:

```powershell
.\bin\nucleor.exe build tests\features\rfc0007_atomic_width_wrappers.nr -o helper1_atomic_width_wrappers --no-cache
.\target\helper1_atomic_width_wrappers.exe
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/rfc0007_atomic_width_wrappers" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/rfc0007_atomic_basic" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/rfc0007_atomic_bool" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/concurrency_disclosure_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
git diff --check
```

Direct build/run result: PASS. The build emits expected NUM-003 warnings at the
i64-to-i32 typed wrapper boundary; the fixture stays within small in-range test
values and exits 0.

Focused verify results:

- `tools/verify.sh --sequential-fixtures --only "test features/rfc0007_atomic_width_wrappers"`: PASS
- `tools/verify.sh --sequential-fixtures --only "test features/rfc0007_atomic_basic"`: PASS
- `tools/verify.sh --sequential-fixtures --only "test features/rfc0007_atomic_bool"`: PASS
- `tools/verify.sh --sequential-fixtures --only "test features/concurrency_disclosure_smoke"`: PASS
