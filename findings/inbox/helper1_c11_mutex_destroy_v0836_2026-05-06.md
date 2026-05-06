# Helper1 C-11 Mutex Destroy Closure

Date: 2026-05-06
Branch: `fix/helper1-quantum-robotics-residuals-v0835`
Scope: C-11 concurrency mutex lifecycle

## Summary

C-11 is closed for Phase 1. `concurrency.nr` now exposes explicit
`conc_mutex_destroy` and `conc_mutex_free` wrappers for handles allocated by
`conc_mutex()`. The runtime adds `__nucleor_mutex_free` on both Win32 and POSIX:
it destroys the native mutex (`DeleteCriticalSection` or
`pthread_mutex_destroy`) and frees the heap handle.

This is an explicit lifecycle API, not RAII Drop integration. Automatic cleanup
remains a future memory-safety/auto-drop lane.

## Files

- `stdlib/runtime/nucleor_llvm_rt.c`
- `stdlib/rods/concurrency.nr`
- `tests/features/concurrency_mutex_destroy_smoke.nr`
- `tests/features/concurrency_disclosure_smoke.nr`
- `docs/rfcs/v1_PUNCHLIST.md`
- `docs/rfcs/gap-analyses/Nucleor_Concurrency_Gap_Analysis_and_RFC_2026-05-04.md`

## Validation

Completed before integration:

```powershell
.\bin\nucleor.exe build tests\features\concurrency_mutex_destroy_smoke.nr -o helper1_concurrency_mutex_destroy --no-cache
.\target\helper1_concurrency_mutex_destroy.exe
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/concurrency_mutex_destroy_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/concurrency_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/concurrency_disclosure_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
git diff --check
```

Results:

- Direct build/run: PASS
- `tools/verify.sh --sequential-fixtures --only "test features/concurrency_mutex_destroy_smoke"`: PASS
- `tools/verify.sh --sequential-fixtures --only "test features/concurrency_smoke"`: PASS
- `tools/verify.sh --sequential-fixtures --only "test features/concurrency_disclosure_smoke"`: PASS
- `git diff --check`: PASS
