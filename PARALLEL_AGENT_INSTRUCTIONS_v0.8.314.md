# Parallel Agent Instructions - post-v0.8.314

> Drafted 2026-05-05 by Codex on user instruction.
> Read this end-to-end before editing code. This supersedes
> `PARALLEL_AGENT_INSTRUCTIONS_v0.6.72.md`,
> `PARALLEL_AGENT_PUNCHLIST_v0.6.54.md`, and
> `findings/_parallel_agent_assignment_v0851_2026-05-05.md` for the
> current helper lane.

## Current main state

- Canonical repo: `C:\Users\JoeWe\Desktop\Nucleor_OSS`
- Branch: `main`
- Current `origin/main`: fetch it live before creating the helper branch
- Compiler baseline underneath this handoff: `fa445e60` / `v0.8.314`
- Self-host fixed-point md5: `92a6b77baec09726f3c04b3224280ce5`
- Handoff from previous main agent:
  `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\HANDOFF_FOR_NEXT_AGENT_2026-05-05.md`
- Canonical spine:
  `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_Build_Spine\BUILD_PATH_v0.4_to_v1.3.md`
- Audit build plans:
  `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_Build_Spine\11_AUDIT_2026-05-05\build_plans`

## Mission

We are in the final buildout lane. The old numbered 1-13 punchlist is
closed. The active list is the audit-derived v1.0-launch-blocker list
from spine section 14.4, with section 15 locking the decision to build
real algebraic-law support rather than demarket it.

Main agent is taking the high-risk compiler lane. Helper agent should
work on substantial, non-overlapping items that can be prepared on a
separate branch and integrated by main after review.

The user mandate is strict:

- Finish the remaining build components.
- Do not settle for performance drift.
- Keep cold compile in the sub-4-second regime.
- Keep peak memory minimal; the cap is an emergency stop, not a budget.
- Prefer real implementation over disclosure-only work when the build
  plan has a real path.

## Non-negotiable workflow

1. Do not edit `C:\Users\JoeWe\Desktop\Nucleor_OSS` directly.
2. Work from a fresh branch or worktree based on current `origin/main`.
3. Push only to a probe/helper branch, never to `main`.
4. Do not tag releases.
5. Do not regenerate `bin/nucleor.exe` or `bootstrap/nucleor_s1_seed.ll`
   unless your branch touches `compiler/nucleor_s1_compiler.nr` and the
   main agent explicitly asks for a compiler-source deliverable.
6. Update `findings/heartbeat.json` in your branch with the current task,
   base commit, validation, and perf numbers.
7. Stop at `ready-for-integration`; main agent owns cherry-pick, version,
   changelog, tag, and final push.

Suggested setup:

```powershell
git -C C:\Users\JoeWe\Desktop\Nucleor_OSS fetch origin
git -C C:\Users\JoeWe\Desktop\Nucleor_OSS worktree add C:\Users\JoeWe\Nucleor_OSS_helper_r12_registry -b probe/r12-registry-remotes-v0814 origin/main
cd C:\Users\JoeWe\Nucleor_OSS_helper_r12_registry
git log --oneline -1
git merge-base HEAD origin/main
```

The merge-base must match fetched `origin/main` before the
work is meaningful.

## Assigned helper lane

Primary assignment:

- `R12-D2` - registry remotes Phase 1 real implementation.
- Assignment file:
  `C:\Users\JoeWe\Desktop\Nucleor_OSS\findings\_parallel_agent_assignment_v0814_2026-05-05.md`

This is intentionally selected because it is substantial but should not
block the main compiler lane. It is expected to touch the tools-suite,
docs, and focused tests rather than the self-host compiler seed path.

If `R12-D2` finishes cleanly, secondary assignments are:

1. `R10-D5` Phase 2 investigation/patch: separate compiler-only vs
   linked-process memory reporting without relaxing any threshold.
2. `R12-D1` POSIX proof prep: source audit plus a proposed
   `tools/native_release.sh` parity path, but do not fake Linux proof
   from Windows.
3. `S03-D1` governance CLI surface prep: decide and wire an explicit
   `nuc gov` dispatch surface if it can be done in tools-suite only.

Do not start `R09-D1`, `R05-D2`, `R04-D2`, `R04-D4`, or `R14 Phase 2`
unless main explicitly reassigns you. Those overlap compiler-lane work
or need tighter sequencing.

## Perf rule

Current performance reality from `v0.8.314`:

- Compiler self-time: about 2.5-2.8s.
- Linked cold wall time: usually high-3s, but Windows Defender / clang
  link variance can push samples above 4s.
- Peak memory: roughly 305-312 MB.

For helper branches:

- Run `powershell -NoProfile -ExecutionPolicy Bypass -File tools/check_perf_regression.ps1`
  before signaling ready-for-integration.
- If touching only `compiler/nucleor_tools_suite.nr`, stdlib rods, docs,
  or tests, cold compile should not materially move. If it does, record
  the numbers and do not ask main to integrate until the cause is clear.
- Do not edit `tools/perf_baseline.json` to absorb a regression.

## Validation expectations

For tools-suite-only work:

```powershell
.\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o target\nucleor_tools.exe
bash tools/check_compiler_drift.sh
powershell -NoProfile -ExecutionPolicy Bypass -File tools/check_perf_regression.ps1
```

Run focused command-level tests for the new CLI surface. If the command
needs a fixture registry, create a small fixture under `tests/fixtures`
or `tests/features` following existing patterns.

If you touch any rod manifest surface, run:

```powershell
python tools/gen_rod_manifest.py
```

If you touch release index material, run:

```powershell
python tools/gen_releases_index.py
```

## Heartbeat schema

Set or update the following fields in your branch's
`findings/heartbeat.json`:

```json
{
  "instructions_read": "v0.8.314-helper-final-buildout",
  "current_task": "helper: R12-D2 registry remotes Phase 1",
  "roadmap_phase": "v1_launch_blocker_final_buildout",
  "current_punchlist_item": "R12-D2",
  "edits_in_main_tree": false,
  "rebased_on_origin_main": "current-origin-main-after-fetch",
  "branch": "probe/r12-registry-remotes-v0814",
  "status": "in_progress",
  "validation": {},
  "perf": {}
}
```

When complete, change `status` to `ready-for-integration` and include:

- exact branch name and HEAD
- merge-base against `origin/main`
- changed file list
- focused test commands and results
- perf command result
- any caveats or known follow-up phases

## What main is doing in parallel

Main agent is expected to take an ambitious compiler item from the
remaining punchlist, starting with `R09-D1` full `fixed<I,F>` type
tracking unless the user redirects.

Avoid conflicts with:

- `compiler/nucleor_s1_compiler.nr`
- `bootstrap/nucleor_s1_seed.ll`
- `bin/nucleor.exe`
- R14 Phase 2 law-check work
- R05/R04/R09 type-system enforcement work

## Stop conditions

Stop and report rather than push if:

- your branch is not based on fetched `origin/main`
- the change requires compiler fixed-point rotation
- cold compile regresses and you cannot explain it
- a command needs Linux/POSIX proof that cannot be honestly run on this
  Windows host
- implementation would require changing main-agent-owned compiler files

The right deliverable is a clean branch plus a clear heartbeat. Main
will integrate after review.
