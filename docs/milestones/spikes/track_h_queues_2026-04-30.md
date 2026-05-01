# Track H Artifact: Lock-Free SPSC + MPSC Queues

Branch: `v05-track-h-queues`
Base: `origin/v05-track-g-atomics` at `c2706132f17c5876260ffb8c0e9156e27efff990`
Scope: Round 2 Track H, lock-free queue rods built on Track G atomics.

## Summary

Track H ships two bounded queue rods:

- `stdlib/rods/spsc_queue.nr`: single-producer/single-consumer Lamport ring buffer using `AtomicI64` head/tail counters.
- `stdlib/rods/mpsc_queue.nr`: multi-producer/single-consumer bounded sequence ring using `AtomicI64` head/tail counters, per-slot sequence numbers, and CAS tail reservation.

The public API matches the required shape:

- `spsc_new<T>(capacity: i64) -> SpscQueue<T>`
- `spsc_push(&mut SpscQueue<T>, val: T) -> bool`
- `spsc_pop(&mut SpscQueue<T>) -> Option<T>`
- `spsc_len(&SpscQueue<T>) -> i64`
- `spsc_capacity(&SpscQueue<T>) -> i64`
- `mpsc_new<T>(capacity: i64) -> MpscQueue<T>`
- `mpsc_push(&mut MpscQueue<T>, val: T) -> bool`
- `mpsc_pop(&mut MpscQueue<T>) -> Option<T>`
- `mpsc_len(&MpscQueue<T>) -> i64`
- `mpsc_capacity(&MpscQueue<T>) -> i64`

The slot storage is `Vec<Option<T>>`, so construction does not need an artificial default value for `T`. Non-positive capacity is normalized to `1`; no new diagnostic code was necessary.

## Algorithm Choices

SPSC uses a Lamport bounded ring:

- Producer reads `head` with Acquire, writes slot, then publishes `tail` with Release.
- Consumer reads `tail` with Acquire, reads slot, clears it to `None`, then publishes `head` with Release.
- Full condition is `tail - head >= capacity`; empty condition is `head >= tail`.

MPSC uses a bounded sequence-number ring:

- Each slot has an `AtomicI64` sequence initialized to its slot index.
- Producers load `tail`, inspect the slot sequence, then reserve a ticket with `atomic_compare_exchange(&tail, old, old + 1, AcqRel, Acquire)`.
- After writing the slot, the producer stores `ticket + 1` to the slot sequence with Release.
- The single consumer reads the slot whose sequence equals `head + 1`, clears it, advances `head`, and releases the slot by storing `head + capacity` into its sequence.

This is the practical Vyukov-style bounded sequence ring adapted to the current Nucleor `AtomicI64` surface.

## Concurrency Evidence

Thread support exists in the repo today through:

- `thread_spawn(fn_ptr, arg)` / `thread_join(handle)` builtins.
- `tests/smoke/t28_async_threads.nr`, which validates thread-backed async spawn/await.
- `tests/runtime/concurrency.nr`, which validates the structured concurrency wrapper path.

The MPSC fixture uses the builtin thread path directly. It spawns four producers, each pushing through a shared `&MpscShared` value. Producers allocate unique values with `AtomicI64 ticket`, push into the same `MpscQueue<i64>`, join, and the consumer verifies every value appears exactly once.

## Fixtures

Added feature fixtures:

- `tests/features/rfc0007_queue_spsc.nr`: SPSC push-N/pop-N round trip with order verification.
- `tests/features/rfc0007_queue_mpsc.nr`: four-producer MPSC concurrency test with duplicate/missing-value detection.
- `tests/features/rfc0007_queue_capacity.nr`: SPSC and MPSC capacity exhaustion and slot reuse.
- `tests/features/rfc0007_queue_bench.nr`: benchmark smoke comparing SPSC/MPSC against the existing mutex-protected `queue.nr` baseline.

Verify gate wiring:

- `tools/verify.sh`: new explicit `RFC-0007 queues run SPSC/MPSC/capacity/benchmark fixtures` step.
- `tools/verify.ps1`: same step mirrored; the script was also normalized to ASCII punctuation so Windows PowerShell parses it reliably.
- `docs/rfcs/rod_manifest.toml`: regenerated to include `spsc_queue` and `mpsc_queue`.

## Benchmark Methodology

The benchmark fixture uses `time_mono_ns()` from `stdlib/rods/time_typed.nr`.

Measured workloads:

- `spsc`: one producer loop pushes 20,000 values, then one consumer loop pops 20,000 values.
- `mpsc`: same 20,000 push/pop loop through the MPSC algorithm without producer contention.
- `mutex_queue`: existing `stdlib/rods/queue.nr` wrapped with `mutex_lock`/`mutex_unlock` around each push and pop.
- `mpsc_4prod`: four OS threads each push 2,000 values into one MPSC queue, then one consumer pops all values.
- `mutex_queue_4prod`: four OS threads each push 2,000 values into the existing queue under one mutex, then one consumer pops under the mutex.

Final benchmark sample:

```text
OK rfc0007_queue_bench
spsc: 22459300 ns for 40000 ops
mpsc: 39539800 ns for 40000 ops
mutex_queue: 938900 ns for 40000 ops
mpsc_4prod: 31402700 ns for 16000 ops
mutex_queue_4prod: 4610600 ns for 16000 ops
```

Approximate throughput from that sample:

- SPSC: ~1.78M ops/s
- MPSC uncontended: ~1.01M ops/s
- Mutex queue uncontended: ~42.60M ops/s
- MPSC 4-producer: ~0.51M ops/s
- Mutex queue 4-producer: ~3.47M ops/s

Interpretation: the current pure-Nucleor lock-free queues are functionally correct and genuinely concurrent, but slower than the C-runtime mutex baseline in this microbenchmark. The cost is expected from generic `Option<T>` slot traffic plus multiple Nucleor-level atomic calls per operation. The shipped value here is correctness and lock-free semantics on the Track G atomic substrate, not a claim of beating the existing C mutex queue on this host.

## Validation

Focused fixtures:

```text
bin\nucleor.exe build tests\features\rfc0007_queue_spsc.nr -o _rfc0007_queue_spsc --no-cache
target\_rfc0007_queue_spsc.exe
=> OK rfc0007_queue_spsc

bin\nucleor.exe build tests\features\rfc0007_queue_mpsc.nr -o _rfc0007_queue_mpsc --no-cache
target\_rfc0007_queue_mpsc.exe
=> OK rfc0007_queue_mpsc

bin\nucleor.exe build tests\features\rfc0007_queue_capacity.nr -o _rfc0007_queue_capacity --no-cache
target\_rfc0007_queue_capacity.exe
=> OK rfc0007_queue_capacity

bin\nucleor.exe build tests\features\rfc0007_queue_bench.nr -o _rfc0007_queue_bench --no-cache
target\_rfc0007_queue_bench.exe
=> OK rfc0007_queue_bench
```

Compiler/tools memory builds:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File tools\measure_peak_build.ps1 -Source compiler\nucleor_s1_compiler.nr -OutName track_h_compiler_measure -BudgetMb 1024 -TimeoutSec 180
=> peak 543 MB / 1024 MB, wall 4.017s

powershell -NoProfile -ExecutionPolicy Bypass -File tools\measure_peak_build.ps1 -Source compiler\nucleor_tools_suite.nr -OutName track_h_tools_measure -BudgetMb 1024 -TimeoutSec 180
=> peak 439 MB / 1024 MB, wall 3.162s
```

NUM-024 audit:

```text
NUCLEOR_AUDIT_NUM024=1 compiler/tools-suite builds
=> NUM-024 compiler=0 tools-suite=0
```

Two-stage fixed point:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File tools\measure_peak_build.ps1 -Source compiler\nucleor_s1_compiler.nr -OutName stage_h_l -BudgetMb 1024 -TimeoutSec 180 -Bin bin\nucleor.exe
=> peak 477 MB / 1024 MB, wall 3.627s

powershell -NoProfile -ExecutionPolicy Bypass -File tools\measure_peak_build.ps1 -Source compiler\nucleor_s1_compiler.nr -OutName stage_h_m -BudgetMb 1024 -TimeoutSec 180 -Bin target\stage_h_l.exe
=> peak 487 MB / 1024 MB, wall 3.553s

stage_h_l.ll == stage_h_m.ll
SHA256: C725C34D70F0143B5F01E0A4E771B99B339F6E789FAFA5BD919A7DB76F803A31
```

Full verify, env-off:

```text
& 'C:\Program Files\Git\bin\bash.exe' -lc "export NUCLEOR_MEM_CAP_KB=1048576; export NUCLEOR_INT_STRICT_INTRIN=0; ./tools/verify.sh --no-color"
=> PASS: 627
=> SKIP: 1
=> self-host memory budget: peak 485 MB / 550 MB
=> tools-suite memory budget: peak 411 MB / 500 MB
```

Full verify, env-on:

```text
& 'C:\Program Files\Git\bin\bash.exe' -lc "export NUCLEOR_MEM_CAP_KB=1048576; unset NUCLEOR_INT_STRICT_INTRIN; ./tools/verify.sh --no-color"
=> PASS: 627
=> SKIP: 1
=> self-host memory budget: peak 549 MB / 550 MB
=> tools-suite memory budget: peak 479 MB / 500 MB
```

Other checks:

```text
./tools/check_compiler_drift.sh
=> OK: tools-suite ABI tables match nucleor_s1_compiler.nr
=> OK: helper_manifest.toml is up to date
=> OK: rod_manifest.toml is up to date
=> OK: RELEASES.md is up to date

./tools/check_mojibake.sh
=> OK: no mojibake byte sequences detected

Windows PowerShell parser check for tools\verify.ps1
=> verify.ps1 parse OK
```

## Notes

- No compiler source or tools-suite source changes were required for Track H; Track H builds on Track G atomics.
- No new misuse diagnostics were added. Queue capacity exhaustion is a normal runtime condition surfaced by `false` from `push`; non-positive construction capacity is normalized to `1`.
- The branch remained isolated in `C:\Users\JoeWe\Desktop\Nucleor_OSS_track_h`. The main worktree was not edited and no push to `origin/main` is part of this track.
