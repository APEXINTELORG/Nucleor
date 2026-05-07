# Lane 8 / Queue 8A — Platform-aware POSIX perf baseline selection

Date: 2026-05-07 (UTC)
Agent: cloud claude (Cloud_Control1.md punchlist)
Branch (harness-assigned): `claude/cloud-control-punchlist-bPLVn`
Punchlist-named branch: `fix/cloud-linux-perf-platform-baseline-select-v0845` (not used; harness pinned a single branch for the run — see "Branch deviation" below)
Base: `origin/main` @ `5890c84603bd46fc6d86b9500b2ef7cd4ae4d63c`

## Branch deviation

The Cloud_Control1.md instructions ask for `fix/cloud-linux-perf-platform-baseline-select-v0845`. The harness mandate (`Important Instructions`) pins this session to `claude/cloud-control-punchlist-bPLVn`. I followed the harness, since deviating would fail the harness branch contract. Commits are scoped per-queue so the diff for 8A is isolated and could be cherry-picked onto the punchlist-named branch later.

## Host

```
Linux vm 6.18.5 #2 SMP PREEMPT_DYNAMIC Wed Jan 14 17:56:08 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux
```

## Tool versions

```
clang   = Ubuntu clang version 18.1.3 (1ubuntu1)  [/usr/bin/clang]
cargo   = 1.94.1 (29ea6fb6a 2026-03-24)            [/root/.cargo/bin/cargo]
rustc   = 1.94.1 (e408947bf 2026-03-25)
bash    = GNU bash 5.2.21(1)-release
pwsh    = (not on PATH — Linux box)
ssh-keygen = (not on PATH; not exercised by this queue)
```

## Goal

`tools/check_perf_regression.sh` should select `tools/perf_baseline_linux.json` by default on true Linux (non-WSL); continue refusing WSL/Wine/Windows `.exe` evidence; and a user-supplied `--baseline` must still take precedence.

## Files changed

- `tools/check_perf_regression.sh`
  - `is_wsl()` moved above arg parsing.
  - New `default_baseline_for_host()` helper: returns `tools/perf_baseline_linux.json` on `uname -s = Linux` and non-WSL when the file exists; otherwise `tools/perf_baseline.json`.
  - `baseline=""` is now a sentinel; the platform-aware default is filled in only when the user did not pass `--baseline`.
  - Doctor's `baseline-and-source` line now reports `(linux platform default)` or `(windows/legacy default)` so the picker is observable.
- `tools/verify.sh`
  - `posix_perf_regression_monitor` no longer hardcodes `--baseline tools/perf_baseline.json`. It calls the script with no `--baseline` so the platform-aware default kicks in. Setting `NUC_VERIFY_POSIX_PERF_BASELINE=<path>` still pins a specific baseline.

WSL / Wine / `.exe` rejection is unchanged — those paths run unconditionally below, after the default selection.

## Validation

### `uname -a`

```
Linux vm 6.18.5 #2 SMP PREEMPT_DYNAMIC Wed Jan 14 17:56:08 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux
```

### `bash tools/check_perf_regression.sh --doctor` (no --baseline)

Auto-selects the Linux baseline:

```
doctor native-linux: OK - kernel=Linux osrelease=6.18.5
doctor linux-proc: OK - /proc is present
doctor required-shell-tools: OK - awk grep sed sort date mktemp rm tail bash setsid
doctor clang: OK - /usr/bin/clang
doctor run-capped: OK - /home/user/Nucleor/tools/run_capped.sh
doctor baseline-and-source: OK - baseline=/home/user/Nucleor/tools/perf_baseline_linux.json (linux platform default) source=/home/user/Nucleor/compiler/nucleor_s1_compiler.nr
doctor native-executable: FAIL - native /home/user/Nucleor/bin/nucleor is missing or not executable; bin/nucleor.exe is Windows-only
doctor elf-proof: FAIL - cannot inspect missing binary: /home/user/Nucleor/bin/nucleor
doctor result: unsupported for native POSIX perf evidence
```

Exit code: 96 (expected pre-bootstrap; the picker line is the relevant evidence).

### `--baseline` override still wins

```
$ bash tools/check_perf_regression.sh --doctor --baseline tools/perf_baseline.json | grep baseline-and-source
doctor baseline-and-source: OK - baseline=tools/perf_baseline.json (windows/legacy default) source=/home/user/Nucleor/compiler/nucleor_s1_compiler.nr
```

### Bootstrap native binary then re-run

```
$ bash tools/bootstrap_linux.sh    (excerpted)
==> bootstrap complete: bin/nucleor ready
    stage-1 binary: 2198408 bytes
    stage-1 --version: nucleor 0.8.323 (self-hosted, llvm backend)
    fixed point: sha256=8054711c0cbc98aeb0c3c5410667fe5b2c6d3823f255942ef758e33b0e347143
    stage-2 binary: 2198400 bytes
```

### `bash tools/check_perf_regression.sh --verbose`  (auto-select Linux baseline)

```
sample cold 1: 6.040s, process_tree=322MB, cache: miss -> stored (sha=b6cb351676b4, size 12 MB)
sample cold 2: 6.033s, process_tree=323MB, cache: miss -> stored (sha=b6cb351676b4, size 12 MB)
sample cold 3: 6.814s, process_tree=322MB, cache: miss -> stored (sha=b6cb351676b4, size 12 MB)
sample hot 1: 0.668s, process_tree=57MB, cache: hit (sha=b6cb351676b4, size 12 MB)
sample hot 2: 0.663s, process_tree=57MB, cache: hit (sha=b6cb351676b4, size 12 MB)
sample hot 3: 0.662s, process_tree=57MB, cache: hit (sha=b6cb351676b4, size 12 MB)
OK POSIX perf: cold=6.04s (max 10.0s) | hot=0.66s (max 1.0s) | mem cold_tree=323/350MB cold_compiler=n/a hot_tree=57/64MB hot_compiler=n/a
  note: POSIX gate enforces Linux process-tree RSS via tools/run_capped.sh; compiler-only RSS split remains Windows-only in this prep branch.
```

Exit code: 0. All four medians under their Linux ceilings (cold 6.04s ≤ 10.0s, hot 0.66s ≤ 1.0s, cold tree 323 MB ≤ 350 MB, hot tree 57 MB ≤ 64 MB).

### `bash tools/verify.sh --only "T1.8 POSIX perf + memory regression monitor"`

Note: the punchlist's `--only "POSIX cold/hot perf regression"` does not match any registered step. The actual step name is `T1.8 POSIX perf + memory regression monitor`. Reported as a residual below.

```
[ 62/1273] OK    T1.8 POSIX perf + memory regression monitor  ( 20.32s)
```

`PASS: 1`. Verify wires through the new platform-aware default end-to-end.

## Residuals

- The handoff and Cloud_Control1.md reference `--only "POSIX cold/hot perf regression"`, but the registered step name is `T1.8 POSIX perf + memory regression monitor`. Either docs should be updated or `step` registration aliased. Filed as a doc residual; not patching here to keep this branch focused on the baseline picker.
- Cold p50 6.04s is well above the locked Linux baseline 9.05s ceiling-of-record (which lives at `cold_max_allowed_seconds=10.0`). Suggests the Linux baseline is conservative on this runner. No bump applied — the rule is "never -Update to absorb a regression" (it is also "do not update to absorb an improvement" without an explicit measurement burst). Logged for awareness.
- `pwsh` and `ssh-keygen` are absent on this runner; they are not exercised by 8A but will matter for 8B.
