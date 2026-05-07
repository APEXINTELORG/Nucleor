# Cloud PROBE-1L — BLOCKED on partner fixtures

## Summary

PROBE-1L cannot run today. The partner-team-side prerequisites are
missing on `origin/main @ fccef882`:

1. `tests/probes/` directory does not exist (`bfs: error: tests/probes: No such file or directory`).
2. No `tests/probes/real_world/<NN>_<flow>.nr` drivers committed.
3. `tools/verify.sh` does not reference `NUC_VERIFY_PROBE`
   (`grep -rE "NUC_VERIFY_PROBE" tools/` returns 0 matches).

The Cloud_Control1.md PROBE-1 queue (line 235) describes the
prerequisite as "Partner team is building ~30-LOC real-world drivers
under `tests/probes/real_world/<NN>_<flow>.nr` covering `nuc init /
build / test / clean / port / inspect / explain / check`". Until that
build lands, the cloud-side pair-validate cannot run.

## Verification commands

```
$ git log --oneline -1 origin/main
fccef882 docs: production-readiness plan + kludge survey

$ find tests -type d -name "probe*"
(empty)

$ ls tests/probes 2>&1
ls: cannot access 'tests/probes': No such file or directory

$ grep -rE "NUC_VERIFY_PROBE" tools/
(empty)

$ bash tools/verify.sh --only "Cloud-PROBE-1" 2>&1 | head -3
(no matching step — would skip everything if invoked)
```

## What's needed before PROBE-1L can run

Per the queue spec, partner team needs to:
1. Create `tests/probes/real_world/<NN>_<flow>.nr` drivers (~30 LOC each).
2. Add a `NUC_VERIFY_PROBE=1`-gated section to `tools/verify.sh`
   that iterates the drivers, captures exit codes, and asserts
   on-disk artifact presence.
3. Land both as one ship on `origin/main`.

When that ship lands:
- Cloud rebases the harness branch onto current `origin/main`.
- Runs `NUC_VERIFY_PROBE=1 bash tools/verify.sh` end-to-end.
- Reports per-probe outcomes per the PROBE-1L spec.

## Status

Cloud is **ready to start PROBE-1L** the moment the partner ship
lands. No Linux-side blocker; this is a sequencing dependency.

## Files

- `findings/inbox/cloud_claude_probe1L_blocker_v0846_2026-05-07.md` (this report)

Branch: harness-pinned `claude/verify-round-3-tests-RnTlO`.
