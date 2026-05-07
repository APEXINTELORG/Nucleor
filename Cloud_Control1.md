# Cloud_Control1 — Linux/CI/Release Lane

**Source of truth for cloud Linux agent(s).** Append-only. Mark items `[x]` when complete. Add findings/spike requests as new entries below — never edit prior lines.

Spawned cloud agents look here first, take the next pending queue, work it in their own clone, push the named branch, and append a completion entry.

## Operating rules

- Native Linux only. No WSL, no Wine, no Windows `.exe` artifacts, no fake green transcripts.
- One agent, one clone. Do not share checkouts.
- Branch from fresh `origin/main`. Push the named branch. Write `findings/inbox/<agent>_<lane>_<queue>_v0845_2026-05-07.md`.
- Every report must include `uname -a`, tool version probes (`command -v clang`, `command -v pwsh`, `command -v ssh-keygen`, `command -v cargo`), exact commands run, and exact pass/fail output.
- If a Linux prerequisite is missing, write a blocker naming the exact missing tool and the smallest docs/tooling patch needed. Do not fake it.
- No Python helpers in product/toolchain paths.
- When out of work: append `## Spike request` block at bottom and stop.
- Full handoff context: `docs/rfcs/v1_REMAINING_PUNCHLIST_AGENT_HANDOFF_v0845_2026-05-07.md`.

## Assigned queues (in order)

- [x] **8A** — Platform-aware POSIX perf baseline selection. Branch `fix/cloud-linux-perf-platform-baseline-select-v0845`. Ensure `tools/check_perf_regression.sh` selects `tools/perf_baseline_linux.json` by default on true Linux; continue refusing WSL/Wine/Windows `.exe` evidence. Validate:
  ```
  uname -a
  bash tools/check_perf_regression.sh
  bash tools/verify.sh --only "POSIX cold/hot perf regression"
  ```
  Handoff §Lane 8 / Queue 8A.

- [x] **8B** — Linux release prerequisite doctor. Branch `fix/cloud-linux-release-prereq-doctor-v0845`. Small shell/PowerShell doctor or docs section for `pwsh`, `ssh-keygen`, `clang`, `cargo`, `bin/nucleor`, `bin/nucleor_tools`. No Python helper. Handoff §Lane 8 / Queue 8B.

- [ ] **8C** — Full native Linux verify transcript. Branch `probe/cloud-linux-full-verify-transcript-v0845`. Run full `bash tools/verify.sh` on native Linux from current `origin/main`. If it fails, file one report with exact failures classified as: Windows-only fixture / missing Linux prerequisite / real compiler/runtime bug / performance-only drift. Do not patch unrelated failures in this transcript branch unless small + deterministic. Handoff §Lane 8 / Queue 8C.

## Optional follow-on (if 8A-8C close cleanly)

- [ ] **7A-Linux-side** — Pair the POSIX side of R06 hash transcripts (Handoff §Lane 7 / Queue 7A) when Windows-side patch lands. Wait for Windows half on `fix/r06-cross-platform-hash-transcript-v0845` before working this side.

## Per-queue completion entry format

Append below when each queue closes. Do not edit earlier entries.

```
## [DATE TIME UTC] Queue <id> — DONE
Branch: <branch> @ <head sha>
Base: origin/main @ <sha>
Host: <uname -a>
Tools: clang=<ver> pwsh=<ver> cargo=<ver>
Files: <count>
Validation: <pass/fail summary>
Report: findings/inbox/<file>.md
Residuals: <text>
```

For unexpected discoveries:

```
## [DATE TIME UTC] Spike — <title>
Where: <file:line or fixture>
What: <one line>
Action: <queued / blocker / resolved>
```

For empty queue:

```
## [DATE TIME UTC] Spike request — out of assigned work
Last completed: <queue id>
Notes: <any blockers / suggestions>
```

---

## Append-only log starts below this line

## [2026-05-07 11:05 UTC] Queue 8A — DONE
Branch: claude/cloud-control-punchlist-bPLVn @ <committed below>
Base: origin/main @ 5890c84603bd46fc6d86b9500b2ef7cd4ae4d63c
Host: Linux vm 6.18.5 #2 SMP PREEMPT_DYNAMIC Wed Jan 14 17:56:08 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux
Tools: clang=Ubuntu-18.1.3 pwsh=missing cargo=1.94.1 rustc=1.94.1 ssh-keygen=missing
Files: 3 (tools/check_perf_regression.sh, tools/verify.sh, findings/inbox/cloud_claude_lane8_8A_v0845_2026-05-07.md)
Validation: PASS — `bash tools/check_perf_regression.sh` (auto-selected `tools/perf_baseline_linux.json`) cold p50 6.04s ≤ 10.0s, hot p50 0.66s ≤ 1.0s, cold tree 323/350 MB, hot tree 57/64 MB; `bash tools/verify.sh --only "T1.8 POSIX perf + memory regression monitor"` → 1 PASS / 0 FAIL.
Report: findings/inbox/cloud_claude_lane8_8A_v0845_2026-05-07.md
Residuals: (1) punchlist's `--only "POSIX cold/hot perf regression"` does not match any registered verify step — actual name is `T1.8 POSIX perf + memory regression monitor`. (2) Used the harness-pinned branch `claude/cloud-control-punchlist-bPLVn` instead of `fix/cloud-linux-perf-platform-baseline-select-v0845`; commits are scoped per-queue for clean cherry-pick. (3) `pwsh`/`ssh-keygen` absent on this runner — relevant to Queue 8B.

## [2026-05-07 11:18 UTC] Queue 8B — DONE
Branch: claude/cloud-control-punchlist-bPLVn @ <committed below>
Base: origin/main @ 5890c84603bd46fc6d86b9500b2ef7cd4ae4d63c
Host: Linux vm 6.18.5 #2 SMP PREEMPT_DYNAMIC Wed Jan 14 17:56:08 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux
Tools: clang=Ubuntu-18.1.3 pwsh=missing cargo=1.94.1 rustc=1.94.1 ssh-keygen=missing
Files: 3 (tools/release_doctor.sh [new, +x], docs/process/semver-and-release.md [new §3.0 Linux release prerequisites], findings/inbox/cloud_claude_lane8_8B_v0845_2026-05-07.md)
Validation: PASS — `bash tools/release_doctor.sh` reports OK for native-linux/clang/cargo/bin-nucleor/bin-nucleor-tools; FAIL with actionable install hints for the genuinely-missing pwsh and ssh-keygen on this runner. JSON mode validates with `python3 -c json.load`. Quiet mode emits only the summary line. No Python in the doctor itself (`#!/usr/bin/env bash` + awk/grep/sed/file/tr).
Report: findings/inbox/cloud_claude_lane8_8B_v0845_2026-05-07.md
Residuals: (1) `pwsh` and `ssh-keygen` are genuinely absent on this runner — the doctor's docs install-hint table is the smallest tooling/docs patch. (2) No POSIX `tools/native_release.sh` exists yet (PKG-1 P2 future work per the gap-analysis RFC); when it lands, `pwsh` may move from `required` to optional in the doctor.

