# Self-Host Integrity Gate

Status: implemented on `probe/perf-hotpath-followup`.

Punchlist item: E4 / BOOT-3 + BOOT-4.

## Built

- Added `tools/check_self_host_md5.sh`.
- Builds the compiler twice:
  - stage1 from `bin/nucleor[.exe]`
  - stage2 from `target/_self_host_md5_stage1[.exe]`
- Fails if stage1 `.ll` differs from stage2 `.ll`.
- Fails if stage2 `.ll` differs from `bootstrap/nucleor_s1_seed.ll`.
- Supports `--seed PATH` for corrupted-seed failure-path validation without modifying the committed seed.
- Supports `NUCLEOR_SELF_HOST_KEEP=1` for preserving target artifacts during diagnostics.
- Refreshed `bootstrap/nucleor_s1_seed.ll` after rebasing onto v0.8.147 because the new gate caught stale seed drift on current `origin/main`.

## Gate Wiring

- Added `T1.8 self-host compiler IR fixed point` to `tools/verify_fast.sh`.
- Added the same `T1.8` gate to canonical `tools/verify.sh`.
- Kept existing `T1.7 bootstrap seed matches current compiler` as a cheap single-pass seed freshness screen.

## Why It Matters

The old seed check proved only that the host compiler could emit the current committed seed. It did not prove full self-host fixed-point integrity. This gate catches drift where a compiler built from the emitted IR produces different compiler IR on the next round, and it catches stale committed seeds.

On first run after rebasing onto v0.8.147, the gate failed exactly as intended:

- stage2 fixed-point md5: `399ca503c07895fb29f5a30d1e48cabd`
- old committed seed md5: `a8631dcec8e4367c399041436f31b905`

The committed seed is now refreshed to `399ca503c07895fb29f5a30d1e48cabd`.
