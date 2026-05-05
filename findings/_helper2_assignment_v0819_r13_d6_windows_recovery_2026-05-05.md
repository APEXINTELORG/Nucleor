# Second Helper Assignment - R13-D6 Windows Recovery / Cache-Gate Docs

> Created 2026-05-05 by Codex for the second helper lane.
> Read this end-to-end before editing. This helper lane mirrors the
> existing probe/helper workflow: branch from current `origin/main`,
> work outside `main`, update a heartbeat, push the helper branch, and
> stop at `ready-for-integration`.

## 0. Current Base

- Canonical repo: `C:\Users\JoeWe\Desktop\Nucleor_OSS`
- Required base: fetch current `origin/main` before branching.
- Current known `origin/main` at handoff time:
  `5ea94cecbcb07036e8511023829c44c8623b6043`
  (`v0.8.317: split perf memory accounting`)
- Main perf gate at v0.8.317:
  - cold `3.47s` <= `4.00s`
  - hot `0.26s` <= `1.00s`
  - cold process-tree memory `309MB` <= `400MB`
  - cold compiler memory `292MB` <= `350MB`
  - hot process-tree memory `31MB` <= `128MB`
  - hot compiler memory `17MB` <= `64MB`

Use current fetched `origin/main` if it has advanced beyond the hash above.

Suggested worktree setup:

```powershell
git -C C:\Users\JoeWe\Desktop\Nucleor_OSS fetch origin
git -C C:\Users\JoeWe\Desktop\Nucleor_OSS worktree add `
  C:\Users\JoeWe\Nucleor_OSS_helper2_r13_d6_windows_recovery `
  -b probe/r13-d6-windows-recovery-v0819 origin/main
cd C:\Users\JoeWe\Nucleor_OSS_helper2_r13_d6_windows_recovery
git log --oneline -1
git merge-base HEAD origin/main
```

The merge-base must match fetched `origin/main`.

## 1. Primary Assignment

Primary task from main-agent redirect:

**R13-D6 cache/gate docs + Windows recovery docs/script prep.**

Build-plan source:

`C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_Build_Spine\11_AUDIT_2026-05-05\build_plans\BUILD_PLAN_R13_self_hosting_bootstrap.md`

Relevant R13-D6 text:

- Root cause: docs describe old cache path/static gate count and lack
  complete Windows seed recovery tooling.
- Files in scope:
  - `docs/architecture.md`
  - `NUCLEOR_BOOTSTRAP_CONTRACT.md`
  - `bootstrap/README.md`
  - `tools/bootstrap_windows.ps1` if scripted
- Acceptance: docs match current code and a Windows recovery dry-run
  command is documented.

Important live-state note:

R13-D6 Phase 1 already shipped at v0.8.281. That ship refreshed the
cache/gate-count docs and documented a manual Windows recovery command.
Do not redo that blindly. First verify whether the Phase 1 docs still
match current `origin/main`. The likely remaining value is Phase 2:
a guarded `tools/bootstrap_windows.ps1` script plus any small doc updates
needed to reference it honestly.

## 2. Hard Boundaries

Do not edit these paths in the helper branch unless the main agent
explicitly reassigns ownership:

- `compiler/nucleor_s1_compiler.nr`
- `bin/`
- `bootstrap/`
- `tools/perf_baseline.json`
- `CHANGELOG.md`
- `RELEASES.md`

Do not take the first helper's lane:

- First helper continues **S03-D1 governance CLI dispatch prep**.
- First helper branch target:
  `probe/s03-d1-governance-cli-dispatch-prep-v0816`

General constraints:

- Do not push to `main`.
- Do not tag.
- Do not update release/changelog material.
- Do not create new Python toolchain helpers or Python runtime
  dependencies. Existing Python maintenance generators are deferred
  cleanup, not a pattern to extend.
- If the script requires changing compiler source, bootstrap seed, or
  committed binaries, stop and file a finding instead of forcing it.

Read-only inspection of restricted files is allowed when needed to
verify docs, but they are not write targets for this lane.

## 3. Desired R13-D6 Phase 2 Shape

Start with an audit pass:

1. Confirm `docs/architecture.md` cache section describes the live
   `.nuc_cache/` layout.
2. Confirm `NUCLEOR_BOOTSTRAP_CONTRACT.md` uses dynamic gate-count
   wording, not static historical counts.
3. Confirm `NUCLEOR_BOOTSTRAP_CONTRACT.md` has the Windows seed recovery
   command and that the command still matches current linker/runtime
   paths.
4. Check whether `bootstrap/README.md` should cross-link the Windows
   recovery procedure or the new script.

Only if the audit shows a clean tooling-only path, prepare
`tools/bootstrap_windows.ps1`.

Script expectations if implemented:

- PowerShell only. No Python.
- Default to a safe dry-run / command-printing mode.
- Locate `clang.exe` robustly or fail with a clear dependency diagnostic.
- Refuse to overwrite `bin\nucleor.exe` unless an explicit `-Force`
  style flag is passed.
- Use the committed seed and runtime paths by default:
  - `bootstrap\nucleor_s1_seed.ll`
  - `stdlib\runtime\nucleor_llvm_rt.c`
- Include the existing stack flag from the documented command:
  `-Wl,/STACK:16777216`
- Offer a verification mode that runs the fixed-point check only when
  requested and when `bash` is available.
- Document the dry-run command in `NUCLEOR_BOOTSTRAP_CONTRACT.md` and/or
  `bootstrap/README.md`.

If any of the above is not clean, deliver a finding explaining why the
script should not ship yet.

## 4. Validation Contract

Minimum validation before `ready-for-integration`:

```powershell
python -m json.tool findings\heartbeat_helper2.json
git diff --check
```

If `tools/bootstrap_windows.ps1` is added:

```powershell
pwsh -NoProfile -Command "$errors = $null; [System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw tools\bootstrap_windows.ps1), [ref]$errors) | Out-Null; if ($errors.Count) { $errors; exit 1 }"
pwsh -NoProfile -File tools\bootstrap_windows.ps1 -DryRun
```

If verify scripts are touched:

```bash
bash -n tools/verify.sh tools/verify_fast.sh
```

If docs/tooling only, do not run the full verify gate by default. It is
expensive and does not add signal for this lane. A focused script dry run
and syntax validation are the right first gate.

If the branch touches nontrivial tooling behavior, run the current split
perf gate:

```powershell
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

Do not edit `tools/perf_baseline.json` to absorb any regression.

## 5. Heartbeat

Use the dedicated second-helper heartbeat:

`findings/heartbeat_helper2.json`

When starting, set status to `in_progress`. When done, set status to
`ready-for-integration` and include:

- branch name
- branch HEAD
- merge-base against `origin/main`
- changed file list
- validation commands and results
- whether this is docs-only, script-prep, or finding-only
- caveats

Do not overwrite `findings/heartbeat.json`; main and the first helper use
that file for the existing lane.

## 6. Candidate Follow-On Work For Helper 2

Do not start these until main explicitly redirects, but these are good
future lanes because they are less likely to collide with compiler work:

1. **R13-D6 follow-up finding** if Windows recovery cannot be scripted
   safely from the current docs.
2. **R13-D5 POSIX RSS e-stop documentation/probe prep** only as a
   finding or script-design note unless a POSIX host is available.
3. **R10-D3 POSIX perf/repro parity audit** as a non-mutating finding;
   do not edit `tools/perf_baseline.json`.
4. **S04 drift-triage status hygiene** if assigned; docs/findings only.
5. **R08-D5 convergence/autodiff gate inventory** as an evidence/finding
   pass, not a compiler implementation.

Avoid R13-D1 while main finishes it. Avoid S03-D1 while helper 1 owns it.

## 7. Stop Conditions

Stop and report instead of pushing ready-for-integration if:

- merge-base is not current fetched `origin/main`
- the work requires changing any restricted file listed above
- the script would overwrite `bin\nucleor.exe` by default
- the Windows recovery command cannot be dry-run safely
- dependency detection is ambiguous or silently succeeds without `clang`
- perf gate crosses the v0.8.317 ceilings

The correct deliverable is a small branch with docs/tooling prep and a
clear heartbeat, not a forced broad integration.
