# Parallel Agent Assignment - v0.8.316 S03-D1 redirect

**Issued:** 2026-05-05
**Base:** freshly fetched `origin/main` at `c4610e763a3799c43557a3d18ea803bca19882a0` (`v0.8.316`).
**Instruction file:** `PARALLEL_AGENT_INSTRUCTIONS_v0.8.314.md`
**Redirect source:** main-agent redirect after R12-D2 integration.

## Primary assignment: S03-D1 governance CLI dispatch prep

### Why this task

R12-D2 has landed on `origin/main`. The next helper lane is the S03
governance CLI dispatch prep item from the audit build plan:

- Build plan:
  `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_Build_Spine\11_AUDIT_2026-05-05\build_plans\BUILD_PLAN_S03_governance_rod.md`
- Deficiency: `S03-D1`
- One-line: promised `nuc gov` CLI surface is absent or unresolved.
- Current evidence:
  - `docs/rfcs/RFC-0060-governance-rod.md` promises `nuc gov authored / policy / check / evidence / sign / verify / status`.
  - `compiler/nucleor_tools_suite.nr` has top-level `audit`, `policy`, `certify`, `translate`, and `evidence` surfaces, plus governance rod helpers.
  - `compiler/nucleor_s1_compiler.nr` help text already groups governance commands, but does not necessarily prove a top-level `gov` dispatch contract.

### Hard rule

This is dispatch prep, not a forced implementation.

If `nuc gov` can be wired as a clean tools-suite-only shim over existing
surfaces, prepare that narrow patch with focused tests.

If the correct shape requires compiler ownership, runtime ownership,
stdlib rod expansion, signature/evidence semantics, or a design decision
that is not already settled in `origin/main`, do **not** force it. Write
a finding and stop.

### Start commands

```powershell
git fetch origin
git checkout -B probe/s03-d1-governance-cli-dispatch-prep-v0816 origin/main
git log --oneline -1
git merge-base HEAD origin/main
```

Expected base/merge-base:

```text
c4610e763a3799c43557a3d18ea803bca19882a0
```

### Investigation checklist

Read these before editing:

1. `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_Build_Spine\11_AUDIT_2026-05-05\build_plans\BUILD_PLAN_S03_governance_rod.md`
2. `docs/rfcs/RFC-0060-governance-rod.md`
3. `stdlib/rods/governance.nr`
4. `compiler/nucleor_tools_suite.nr`
5. `compiler/nucleor_s1_compiler.nr` help/dispatch surface only
6. Existing gates:
   - `tools/verify.sh`
   - `tools/verify_fast.sh`
   - `tools/verify.ps1`

### Preferred successful deliverable

Only if it stays tools-suite-only and unambiguous:

- Add an explicit `nuc gov` dispatch surface in `compiler/nucleor_tools_suite.nr`.
- Keep it a thin shim over existing behavior. Good candidates:
  - `nuc gov status`
  - `nuc gov check <file>` mapping to current policy/check behavior
  - `nuc gov evidence <file>` mapping to current evidence behavior
  - `nuc gov help`
- Do not claim evidence signing/verification is complete unless it is already complete.
- Add focused smoke coverage in `tools/verify.sh`, `tools/verify_fast.sh`, and `tools/verify.ps1`.
- Update docs only enough to make the actual surface honest.

### Stop-and-file deliverable

If implementation is not obviously tools-suite-only, create a finding under
`findings/inbox/`, for example:

```text
findings/inbox/2026-05-05-s03-d1-governance-cli-dispatch-prep.md
```

The finding must include:

- exact command/docs promise that is missing or ambiguous;
- exact code paths inspected;
- why forcing a shim would be dishonest or incomplete;
- the smallest recommended next implementation step;
- whether main should handle it as compiler, tools-suite, runtime, stdlib, or docs work.

Then update `findings/heartbeat.json` with `status = "blocked-finding-ready"`
and stop. Do not keep iterating.

### Avoid scope

- Do not touch `tools/perf_baseline.json`.
- Do not loosen perf gates.
- Do not create a tag.
- Do not update `CHANGELOG.md` or `RELEASES.md`; main will do release bookkeeping.
- Do not rotate `bin/nucleor.exe` or `bootstrap/nucleor_s1_seed.ll` unless main explicitly asks.
- Do not expand S03-D2 evidence bundle/sign/verify in this assignment.

### Validation if patched

At minimum:

```powershell
.\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o target\nucleor_tools.exe
bash tools/check_compiler_drift.sh
bash tools/verify.sh --only "<new S03-D1 step name>"
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

Perf expectation inherited from `v0.8.316`:

- cold self-build stays below `4.00s`;
- hot self-build stays below `1.00s`;
- process-tree peak memory stays below `400MB`.

### Deliverable

Push only to the helper branch:

```powershell
git push origin probe/s03-d1-governance-cli-dispatch-prep-v0816
```

Update `findings/heartbeat.json` in that branch with:

- `instructions_read = "v0.8.316-s03-d1-redirect"`
- `current_task = "helper: S03-D1 governance CLI dispatch prep"`
- `current_punchlist_item = "S03-D1"`
- `rebased_on_origin_main = "c4610e763a3799c43557a3d18ea803bca19882a0"`
- branch, HEAD, merge-base, changed files, validation, and perf numbers if patched
- either `status = "ready-for-integration"` or `status = "blocked-finding-ready"`

Then stop. Main integrates or sequences the next step.
