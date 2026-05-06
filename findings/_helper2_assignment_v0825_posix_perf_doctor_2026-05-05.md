# Helper2 Assignment v0825 - POSIX Perf Unsupported-Host Doctor

Date: 2026-05-05
Owner: helper2
Base: fetch current `origin/main` first. At assignment creation, `origin/main` was `a37759b83d70ed7952c57c40f4a49ea600d5ed43`.
Branch: `fix/helper2-posix-perf-doctor-v0825`

## Mission

Keep R10-D3 honest and easier to close on a true native Linux runner. The v0824 transcript proved this machine is WSL2 and cannot provide valid POSIX perf/RSS evidence. Do not weaken that refusal.

Add an explicit unsupported-host doctor mode to `tools/check_perf_regression.sh` so a runner can ask why POSIX perf evidence is unavailable before attempting the cold/hot measurements.

Preferred interface:

```bash
bash tools/check_perf_regression.sh --doctor
```

Expected behavior:

- Print one concise status line for each required prerequisite:
  - native Linux kernel, not WSL
  - Linux `/proc`
  - required shell tools
  - `clang`
  - `tools/run_capped.sh`
  - baseline JSON and source file
  - native executable `bin/nucleor`
  - ELF proof when `file` is available
- Exit `0` only when the host is ready to run real POSIX perf evidence.
- Exit `96` when the host is unsupported or missing native prerequisites.
- Do not mark WSL green.
- Do not change perf thresholds, normal sample counts, RSS budgets, or verify semantics.

## Scope

Allowed files:

- `tools/check_perf_regression.sh`
- `tools/VERIFY_TIMING_RECIPE.md` only if a short doctor invocation note is useful
- one report under `findings/inbox/`

Do not touch:

- compiler sources
- stdlib rods
- `bin/`
- `bootstrap/`
- helper1 files
- Python helpers or new Python scripts
- GitHub workflow files unless you stop and report why a workflow is necessary

## Validation

Run at least:

```bash
bash tools/check_perf_regression.sh --help
bash tools/check_perf_regression.sh --doctor
bash tools/check_perf_regression.sh --verbose
bash tools/verify.sh --only "T1.8 POSIX perf + memory regression monitor"
git diff --check
```

On WSL or Windows interop, `--doctor` and `--verbose` may exit `96`; that is expected if the output clearly identifies the unsupported native-Linux blockers. The verify selector should continue to report `SKIP`, not `OK`, on unsupported hosts.

If you happen to be on a true native Linux host with native `bin/nucleor`, run the full perf gate and report the cold/hot/RSS values. Do not fabricate a native transcript from WSL.

## Report

Write:

`findings/inbox/helper2_posix_perf_doctor_v0825_2026-05-05.md`

Include branch, base, host type, exit codes, exact doctor output summary, and whether R10-D3 is still blocked or can close.
