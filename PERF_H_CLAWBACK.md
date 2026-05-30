# §H Perf Clawback — Working Branch

**Branch:** `review/h-perf-clawback`
**Parent:** `review/v1.1.1-TZ8Qc` @ `2dc3cfc1` (§H Phase A landed)
**Goal:** keep §H, claw back the Windows cold-compile regression.

## What happened

§H (RFC-NRT-004 module-prefixed lowering) landed at `2dc3cfc1`. The
implementation is small and the runtime overhead in the compiled compiler
is tiny — a per-import O(few bytes) marker-check on imported files.

But §H *triggered a bin rebuild* (because any change to s1 source forces a
new bootstrap seed, and a new seed needs a matching bin). The rebuilt
`bin/nucleor.exe` necessarily folded in **every accumulated post-v1.1.1
change** that had been sitting in source but not yet in the committed bin:

- DUP-1 (front-end unification, deleted ~363 fns from `ts/`)
- MEM-3 escape analysis in the lowering pass (per-loop-binding `ad_*` checks)
- SEC-1..8 hardening (SHA256 cache hashing, handle magic tags, etc.)
- MEM-6 closure tag-bit ABI (replaced the 2 MB capture table)
- HON-1..5 capability probes
- VER-1..8 gate hardening
- §H itself (3 new fns, ~150 LOC)
- The perf agent's own O(1) ownership fix

None of these are individually large, but the bin grew **1.55 MB → 2.67 MB
(+72%)** and that's where the cold-compile cost shows up.

## Measured numbers (Windows, this machine, Defender exclusions in place)

| State | Cold | Hot | Bin size | Notes |
|---|---|---|---|---|
| Pre-§H, OLD committed bin | **3.548 s** | 0.159 s | 1.55 MB | What we had |
| Post-§H, NEW rebuilt bin | **4.69 s** (+32%) | 0.252 s | 2.67 MB | What we have |

Hot is fine (rounding-noise of the baseline 0.26 s after Defender
exclusions). Cold is the lever to recover.

The perf agent never observed the Windows regression because their commits
to source landed without rebuilding the committed bin, so their Windows
measurements always used the OLD bin compiling new source (~3.5 s).

## What this branch is for

Profile-diff the OLD bin vs the NEW bin compiling the same current source,
identify which phase grew the most, attribute the delta to specific
post-v1.1.1 changes, and optimize without giving up correctness. Realistic
ceiling: probably 4.0–4.2 s (~10–15% recoverable). Won't reach 3.5 s without
reverting correctness work.

## Constraints (non-negotiable)

- **§H stays.** No reverting RFC-NRT-004.
- **Self-host fixed point must hold** through every change. Any compiler
  edit re-triggers seed regen.
- **No giving up on the punchlist's correctness work** (MEM-3, SEC-*, HON-*, MEM-6).

## Next steps (in this branch)

1. Extract OLD bin from `main` (`d92d2421`) for direct A/B profiling.
2. Phase-by-phase diff: `--time-passes` on both, identify the regressed phase.
3. Hot-path inspection in that phase, code-level diff between old and new.
4. Surgical fix; re-profile.
5. Land the perf fix on this branch, push, merge back to TZ8Qc when verified.
