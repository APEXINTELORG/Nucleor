# Helper2 Assignment v0824 - Native Linux POSIX Perf Transcript

Date: 2026-05-05
Owner: helper2
Base: fetch current `origin/main`; expected assignment issue base is `00539b910c7c96e0ea700584071ca5b390c5c70f` or newer
Branch: `probe/helper2-r10-d3-native-linux-perf-transcript-v0824`
Mode: evidence lane; docs/findings only unless a tiny recipe clarification is required

## Objective

Close or precisely block the remaining R10-D3 POSIX cold/hot perf evidence gap.

Current state:

- `tools/check_perf_regression.sh` is wired on main.
- The gate intentionally refuses WSL and Windows `.exe` interop.
- `docs/rfcs/v1_PUNCHLIST.md` still requires a native Linux transcript before
  R10-D3 can be marked closed.

Your target: run the POSIX perf gate on a native Linux host with a native ELF
`bin/nucleor`, capture the transcript, and report whether R10-D3 can close.

If you do not have a true native Linux host, do not fake the result. File the
finding with exact blocker evidence from `uname`, `/proc`, `file bin/nucleor*`,
and the gate's `exit=96` unsupported message.

## Allowed Write Scope

Allowed:

- `findings/inbox/helper2_r10_d3_native_linux_perf_transcript_v0824_2026-05-05.md`
- `docs/rfcs/v1_PUNCHLIST.md` only if native Linux evidence passes and you can
  mark R10-D3 closed accurately
- `tools/VERIFY_TIMING_RECIPE.md` only for a tiny clarification discovered while
  running the native Linux recipe

Do not edit:

- `compiler/`
- `stdlib/`
- `bin/`
- `bootstrap/`
- `tools/check_perf_regression.sh`
- `tools/run_capped.sh`
- `tools/perf_baseline.json`
- `CHANGELOG.md`
- `RELEASES.md`
- helper1 qsim graph files

## Guardrails

- No Python helpers.
- Native Linux means not WSL. The transcript must include enough host evidence
  to prove that.
- Do not lower thresholds to get green.
- Do not claim POSIX closure from Windows or WSL.
- Keep the report concise but copy the key pass/fail lines verbatim.

## Suggested Native Linux Commands

```bash
git fetch origin
git checkout -b probe/helper2-r10-d3-native-linux-perf-transcript-v0824 origin/main
git merge-base HEAD origin/main
git status --short

uname -a
cat /proc/sys/kernel/osrelease
command -v clang || true
file bin/nucleor bin/nucleor.exe 2>/dev/null || true

bash tools/bootstrap_linux.sh --seed-only
file bin/nucleor
bash tools/check_perf_regression.sh --verbose
bash tools/verify.sh --only "T1.8 POSIX perf + memory regression monitor"
git diff --check
```

If `bootstrap_linux.sh --seed-only` fails because LLVM/clang is missing, record
the exact missing-tool output and stop with a blocker finding.

## Required Report Sections

- Summary
- Base and branch
- Host proof
- Native compiler proof
- Commands run
- Perf transcript
- Verify selector transcript
- Whether R10-D3 can close
- Remaining blocker if not closed

## Validation

Required before pushing:

```bash
git diff --check
```

If you edit the punchlist or timing recipe, also run the relevant focused
commands above after the edit.

Push:

```bash
git push -u origin probe/helper2-r10-d3-native-linux-perf-transcript-v0824
```

