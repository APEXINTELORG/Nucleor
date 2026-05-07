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

- [ ] **8A** — Platform-aware POSIX perf baseline selection. Branch `fix/cloud-linux-perf-platform-baseline-select-v0845`. Ensure `tools/check_perf_regression.sh` selects `tools/perf_baseline_linux.json` by default on true Linux; continue refusing WSL/Wine/Windows `.exe` evidence. Validate:
  ```
  uname -a
  bash tools/check_perf_regression.sh
  bash tools/verify.sh --only "POSIX cold/hot perf regression"
  ```
  Handoff §Lane 8 / Queue 8A.

- [ ] **8B** — Linux release prerequisite doctor. Branch `fix/cloud-linux-release-prereq-doctor-v0845`. Small shell/PowerShell doctor or docs section for `pwsh`, `ssh-keygen`, `clang`, `cargo`, `bin/nucleor`, `bin/nucleor_tools`. No Python helper. Handoff §Lane 8 / Queue 8B.

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
