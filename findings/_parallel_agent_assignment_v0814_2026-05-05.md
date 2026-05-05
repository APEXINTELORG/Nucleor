# Parallel Agent Assignment - v0.8.314 final-buildout lane

**Issued:** 2026-05-05
**Base:** freshly fetched `origin/main`, with compiler baseline `fa445e60` / `v0.8.314` underneath.
**Instruction file:** `PARALLEL_AGENT_INSTRUCTIONS_v0.8.314.md`

## Primary assignment: R12-D2 registry remotes Phase 1

### Why this task

The final active punchlist is the audit-derived v1.0-launch-blocker
list. Main agent is taking a compiler-heavy lane. This assignment is a
substantial build item that should stay mostly in the tools-suite and
not block main.

Audit source:

- Build plan:
  `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_Build_Spine\11_AUDIT_2026-05-05\build_plans\BUILD_PLAN_R12_module_packaging.md`
- Deficiency: `R12-D2`
- Evidence: `compiler/nucleor_tools_suite.nr:18629-18641`

Current deficiency: registry remote commands are documented/expected but
not implemented as a real surface.

### Scope

Implement a Phase 1 real registry-remote management surface.

Target behavior should be concrete and testable:

- `nuc registry remote add <name> <url>`
- `nuc registry remote list`
- `nuc registry remote remove <name>`

Recommended storage: keep it local and deterministic. Prefer a simple
project-local metadata file under an existing Nucleor package/config
location if one already exists. If no suitable store exists, use a small
plain-text file in `.nucleor/` with one remote per line. Do not add a
network fetcher in Phase 1.

Phase 1 goal is remote configuration and inspection, not TLS download or
full dependency resolution. Those can remain Phase 2 as long as the CLI
does not silently pretend they work.

### Expected files

Likely files:

- `compiler/nucleor_tools_suite.nr`
- focused CLI/fixture tests under the existing test layout
- docs if current docs overclaim the behavior

Avoid:

- `compiler/nucleor_s1_compiler.nr`
- `bootstrap/nucleor_s1_seed.ll`
- `bin/nucleor.exe`
- `tools/perf_baseline.json`

Do not update `CHANGELOG.md`, `RELEASES.md`, or create a tag. Main will
do that during integration.

### Acceptance criteria

The branch is ready when:

1. `remote add` persists a named remote.
2. `remote list` shows that named remote and URL.
3. `remote remove` removes it.
4. invalid forms fail nonzero with clear text, not silent success.
5. duplicate names and missing names have deterministic behavior.
6. no network access is required.
7. tools-suite rebuild succeeds.
8. compiler drift gate is clean.
9. perf gate has no material regression.

### Suggested validation commands

```powershell
git fetch origin
git log --oneline -1
git merge-base HEAD origin/main

.\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o target\nucleor_tools.exe
bash tools/check_compiler_drift.sh
powershell -NoProfile -ExecutionPolicy Bypass -File tools/check_perf_regression.ps1
```

Add focused command tests matching the repo's existing CLI-test style.
Record exact commands and outputs in `findings/heartbeat.json`.

### Deliverable

Push to a helper/probe branch, for example:

```powershell
git push origin probe/r12-registry-remotes-v0814
```

Update `findings/heartbeat.json` with:

- `instructions_read = "v0.8.314-helper-final-buildout"`
- `current_task = "helper: R12-D2 registry remotes Phase 1"`
- `current_punchlist_item = "R12-D2"`
- `status = "ready-for-integration"` when complete
- branch HEAD, merge-base, changed file list, validation, perf numbers

Then stop. Main agent integrates.

## Secondary queue after R12-D2

Only start these after R12-D2 is ready-for-integration or blocked with a
clear reason.

### Secondary 1: R10-D5 Phase 2 memory reporting split

Goal: improve reporting so cold compile memory and hot compile memory
are visible separately without loosening caps. Touch only perf tooling.
Do not change thresholds to hide drift.

### Secondary 2: R12-D1 POSIX publish-sign proof prep

Goal: source-audit the POSIX path and prepare a real shell parity plan.
If Windows cannot prove it live, say so. Do not fake Linux validation.

### Secondary 3: S03-D1 governance CLI dispatch prep

Goal: make the promised `nuc gov` surface explicit if it can be done in
tools-suite only. If it requires compiler or runtime ownership, write a
finding and stop.

## Standing warning

Cold compile must stay under the 4-second soft target. If your branch
causes drift, fix or stop. Do not ask main to absorb the regression.
