# Helper1 Finding: C-10 Thread Barrier v0836

## Summary

C-10 is closed for the stdlib/runtime barrier surface.

`thread_barrier_new(parties)`, `thread_barrier_wait(barrier)`, and
`thread_barrier_free(barrier)` are now exposed through `stdlib/rods/thread.nr`.
`stdlib/rods/concurrency.nr` documents this path but does not re-export it,
avoiding duplicate `thread_rt.c` linkage when both rods are imported.
The runtime implements a reusable fixed-party barrier with Win32 condition
variables on Windows and pthread condition variables on POSIX.

`thread_barrier_wait` returns:

- `1` to the releasing thread;
- `0` to non-releasing waiters;
- `-1` for invalid handles.

## Changed Files

- `stdlib/runtime/thread_rt.c`
- `stdlib/rods/thread.nr`
- `stdlib/rods/concurrency.nr`
- `tests/features/thread_barrier_smoke.nr`
- `tests/features/concurrency_disclosure_smoke.nr`
- `docs/rfcs/v1_PUNCHLIST.md`
- `docs/rfcs/gap-analyses/Nucleor_Concurrency_Gap_Analysis_and_RFC_2026-05-04.md`

## Validation

```powershell
.\bin\nucleor.exe build tests\features\thread_barrier_smoke.nr -o helper1_thread_barrier --no-cache
.\target\helper1_thread_barrier.exe
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/thread_barrier_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/thread_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/concurrency_disclosure_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
git diff --check
```

Result: PASS.

## Remaining Gap

This closes the missing barrier primitive. It does not implement structured
concurrency `scope { spawn { ... } }`, work stealing, thread-pool resizing, or
panic propagation through futures.
