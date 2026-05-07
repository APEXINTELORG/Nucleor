# Cloud Lane PROBE / Queue Cloud-PROBE-1L — Linux pair-validation of partner PROBE-1

## Summary

**STATUS: DONE.** All 8 nuc subcommand probes PASS on native Linux, both
through the standalone `tests/probes/real_world/probe_runner.sh` script
(8/8 PASS) and through the `NUC_VERIFY_PROBE=1 bash tools/verify.sh`
gate (step 1489/1488 OK in 0.78s).

PROBE-1 is ready to graduate from `NUC_VERIFY_PROBE=1` to default verify
gate per the partner-side ship note.

## Host

```
$ uname -a
Linux vm 6.18.5 #2 SMP PREEMPT_DYNAMIC Wed Jan 14 17:56:08 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux

$ command -v clang && clang --version | head -1
/usr/bin/clang
Ubuntu clang version 18.1.3 (1ubuntu1)

$ command -v cargo && cargo --version
/root/.cargo/bin/cargo
cargo 1.94.1 (29ea6fb6a 2026-03-24)
```

`origin/main` SHA at run time: `a585dd0c` ("Cloud_Control1: append ML
58-failure cluster closure note"). Partner PROBE-1 ship at `027e82fc`
("PROBE-1: real-world driver + 8-subcommand probe runner").

## Standalone runner

```
$ bash tests/probes/real_world/probe_runner.sh
PROBE-1.1 nuc build: PASS
PROBE-1.2 build-then-run: PASS
PROBE-1.3 nuc test: PASS
PROBE-1.4 nuc check: PASS
PROBE-1.5 nuc summary: PASS
PROBE-1.6 nuc explain: PASS
PROBE-1.7 nuc init: PASS
PROBE-1.8 nuc clean: PASS

PROBE-1 runner: 8 passed, 0 failed.
EXIT=0
```

8/8 probes PASS. Each probe asserts both exit code AND on-disk artifact
or output marker (per the partner ship note). All 8 markers verified.

## Verify gate

```
$ NUC_VERIFY_PROBE=1 bash tools/verify.sh
...
[1489/1488] OK    PROBE-1 real-world drivers (nuc build/run/test/check/summary/explain/init/clean)  (  0.78s)
PASS: 1432
SKIP: 1
FAIL: 56
EXIT=0
```

The PROBE-1 step at index 1489/1488 reports OK in 0.78s. (Step count is
1488 because PROBE-1 adds one step to the prior 1487. Index reads
1489/1488 because the gate emits PROBE-1 after the headline counter is
finalized.)

The 56 FAIL count is the ongoing ML latent class — see
`findings/inbox/cloud_claude_evidence_audit_v0846_2026-05-07.md` and
`findings/inbox/main_t21_class_latent_panic_v0846_2026-05-07.md`. NOT
related to PROBE-1; the PROBE-1 step itself is green.

## Verdict

PROBE-1 is Linux-clean. No Linux-only divergence, no platform-specific
path expectations to patch. Ready for graduation to default verify gate.

## Files

- `tests/probes/real_world/probe_runner.sh` (run, no edit)
- `tests/probes/real_world/inventory_score.nr` (run, no edit)
- `tests/probes/real_world/inventory_score_test.nr` (run, no edit)
- `findings/inbox/probe1L_artifacts/standalone.log` (full standalone output)
- `findings/inbox/8O_artifacts/verify_default_with_probe.log` (full verify with PROBE-1 gate)
- `findings/inbox/cloud_claude_probe1L_v0846_2026-05-07.md` (this report)

Branch: harness-pinned `claude/verify-round-3-tests-RnTlO`.
