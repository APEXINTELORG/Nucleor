# Helper1 Assignment v0828: R11-D4 qsim auto-entangle Phase 2a

## Base and Branch

Fetch first and branch from current `origin/main`. Do not reuse an older
helper branch or v0825/v0826 base.

```powershell
git -C C:\Users\JoeWe\Desktop\Nucleor_OSS fetch origin
git -C C:\Users\JoeWe\Desktop\Nucleor_OSS checkout -B fix/helper1-r11-qsim-auto-entangle-v0828 origin/main
git -C C:\Users\JoeWe\Desktop\Nucleor_OSS status --short --branch
git -C C:\Users\JoeWe\Desktop\Nucleor_OSS merge-base HEAD origin/main
```

Current integration base when assigned: `5ec86d7e4d965359348d33826553659157d16016`.

## Scope

Advance R11-D4 without touching compiler source or tool gates.

The qsim graph surface now has status/preflight/checked record wrappers, but
`stdlib/rods/quantum.nr` still does not automatically update the queryable
`qsim_graph` entanglement tracker when qsim entangling gates execute. This
slice should make the normal qsim entangling gate wrappers update
`qsim_graph` entanglement state in the same places where `rods_trace_entangle`
already declares entanglement.

## Required Work

- Update `stdlib/rods/quantum.nr`.
- Prefer importing `stdlib/rods/qsim_graph.nr` and reusing
  `qsim_entangle_register` rather than adding new C runtime symbols.
- Wire auto-registration for the existing entangling wrapper paths:
  - `qsim_cnot(sv, ctrl, tgt)` registers `ctrl,tgt`.
  - `qsim_cz(sv, ctrl, tgt)` registers `ctrl,tgt`.
  - `qsim_crk(sv, ctrl, tgt, k)` registers `ctrl,tgt`.
  - `qsim_ccx(sv, c1, c2, tgt)` registers `c1,tgt` and `c2,tgt`.
  - `qsim_swap` should get the behavior through its existing CNOT calls;
    do not double-register unless needed for correctness.
- Add focused fixture:
  `tests/features/qsim_graph_auto_entangle_smoke.nr`.
- Update `docs/rfcs/v1_PUNCHLIST.md` to mark this as R11-D4 Phase 2a,
  leaving raw gate-DAG auto-recording and thread-safety as open if not fixed.
- Add a report under `findings/inbox/`.

## Non-Scope

- Do not edit `compiler/`, `bin/`, `bootstrap/`, `tools/verify*`, or
  `tools/check_perf_regression*`.
- Do not change the C qsim runtime ABI in this slice.
- Do not attempt full automatic gate-DAG recording unless it is a tiny,
  obviously safe follow-on. Entanglement auto-registration is the deliverable.
- Do not add Python helpers.

## Performance Guardrails

This should be stdlib-only. Do not add compiler passes, source scans, or
verify-time loops. The qsim wrapper overhead should be one `qsim_entangle_register`
call per entangling gate, not a graph walk.

## Validation

Run at minimum:

```powershell
.\bin\nucleor.exe build tests\features\qsim_graph_auto_entangle_smoke.nr -o target\_qsim_auto_entangle --no-cache
.\target\_qsim_auto_entangle.exe
bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_auto_entangle_smoke"
bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_checked_record_smoke"
git diff --check
```

Run `bash tools/check_compiler_drift.sh` if the rod manifest changes. Full
perf gate is not required unless compiler/tooling files change, but if you run
it, the current target remains sub-4s cold and under 400MB process-tree RSS.

## Deliverable

Commit and push the branch. Add:

`findings/inbox/helper1_r11_qsim_auto_entangle_v0828_2026-05-06.md`

Report the branch, commit, merge-base with `origin/main`, exact files changed,
validation results, and the remaining R11-D4 gaps. If importing `qsim_graph.nr`
from `quantum.nr` creates an import/link cycle or duplicated runtime issue,
write the finding and stop instead of widening the patch.

## Append-Only Continuation Queue (2026-05-06)

This section extends the same assignment document. Work top-down. If the next
scope is clean, adjacent to the current qsim files, and validation stays focused,
batch it before pushing. If it widens into compiler, tool gate, C runtime ABI, or
thread-safety work, stop at the previous green commit, write the finding, and
report exactly why it should be split.

Before each continuation scope, fetch and verify the merge-base:

```powershell
git fetch origin
git status --short --branch
git merge-base HEAD origin/main
```

Do not add Python helpers.

### Scope B: R11-D4 Phase 2b qsim gate-DAG auto-record

Prerequisite: Scope A auto-entangle must be locally green.

Wire the same high-level qsim entangling wrappers to record gate-DAG intent via
the existing `qsim_graph` checked-record surface. Prefer
`qsim_gate_record_checked(name, q1, q2)` and the existing status helpers; do not
add new C symbols or change the qsim C ABI.

Required work:

- Record `qsim_cnot`, `qsim_cz`, and `qsim_crk` as checked two-qubit gate events
  after the wrapped qsim operation succeeds.
- For `qsim_ccx`, record the control-target relationships only if the current
  checked-record API can express this cleanly without widening signatures. If not,
  leave a precise finding and keep Phase 2a intact.
- Let `qsim_swap` inherit behavior through existing CNOT calls unless that would
  duplicate records.
- Add or extend a focused feature fixture. Preferred new file if separate:
  `tests/features/qsim_graph_auto_record_smoke.nr`.
- Update `docs/rfcs/v1_PUNCHLIST.md` with the exact Phase 2b status and remaining
  R11-D4 gaps.

Validation:

```powershell
.\bin\nucleor.exe build tests\features\qsim_graph_auto_record_smoke.nr -o target\_qsim_auto_record --no-cache
.\target\_qsim_auto_record.exe
bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_auto_record_smoke"
bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_auto_entangle_smoke"
git diff --check
```

### Scope C: R11-D4 Phase 2c qsim graph closure pack

Only do this if Scopes A and B are green without compiler/tool/runtime ABI
changes.

Close the small docs-and-fixtures gap around the qsim graph wrapper contract:

- Add one boundary fixture for out-of-range or DAG-full status behavior if not
  already covered by the existing checked-record smoke.
- Document the public qsim graph contract and current limits in the closest
  existing qsim/quantum docs. Keep it concise: auto-entangle, auto-record,
  checked status codes, and remaining thread-safety/open runtime gaps.
- Update the report with a short R11-D4 residual-risk list.

Keep this as stdlib/test/docs only. No compiler files, no `bin/`, no
`bootstrap/`, no full verify gate edits.

## Helper1 Status Answer (2026-05-06)

No. I do not have more work remaining in this assignment document; I need a new assignment.

## Append-Only Continuation Queue 2 (2026-05-06)

Continue from this same assignment document. This queue intentionally batches
the next quantum/qsim closure work instead of issuing a tiny one-off scope.
Work top-down and batch adjacent clean scopes in one branch when they stay
within stdlib/tests/docs. Stop at the last green commit and write a finding if
the next scope requires compiler edits, C runtime ABI changes, thread-safety
primitives, bin/bootstrap promotion, verify gate rewrites, or new Python
helpers.

Before starting:

```powershell
git fetch origin
git status --short --branch
git merge-base HEAD origin/main
```

If your branch is not based on current `origin/main`, rebase first and rerun
the focused validation before pushing with `--force-with-lease`.

### Scope D: R11-D4 Phase 2d qsim graph lifecycle and auto-record closure

Goal: lock the high-level qsim auto-graph contract so auto-entangle and
auto-record are not just present, but lifecycle-safe for repeated runs.

Required work:

- Add or extend a focused fixture, preferred new file:
  `tests/features/qsim_graph_lifecycle_auto_record_smoke.nr`.
- Cover at least these behaviors:
  - `qsim_graph_clear()` resets both entanglement and gate-DAG state.
  - A fresh qsim run after clear starts from zero graph/DAG counts.
  - `qsim_cnot`, `qsim_cz`, and `qsim_crk` each add exactly one checked DAG
    record and their expected entanglement relationship.
  - `qsim_swap` records exactly the inherited CNOT sequence, not an extra
    wrapper-level record.
  - `qsim_ccx` keeps the documented two control-target records if the existing
    two-qubit checked-record surface is still the public representation.
- Update `qsim_graph_limitations()` or nearest qsim docs only if the fixture
  reveals stale wording.
- Update `docs/rfcs/v1_PUNCHLIST.md` with a precise Phase 2d status line and
  remaining gap list.

Validation:

```powershell
.\bin\nucleor.exe build tests\features\qsim_graph_lifecycle_auto_record_smoke.nr -o target\_qsim_graph_lifecycle --no-cache
.\target\_qsim_graph_lifecycle.exe
bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_lifecycle_auto_record_smoke"
bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_auto_record_smoke"
bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_auto_entangle_smoke"
git diff --check
```

### Scope E: QM-7 Phase 2b rotated surface-code d=3 evidence fixture

Goal: advance the open QM-7 surface-code closure item with a real fixture, not
a doc-only claim.

Required work:

- Inspect `stdlib/rods/clifford.nr`, `stdlib/runtime/clifford_rt.c`, and the
  existing QM-7 fixtures before editing.
- If the current Clifford public surface can express a rotated planar
  surface-code d=3 stabilizer set cleanly, add:
  `tests/features/qm7_clifford_surface_d3_smoke.nr`.
- The fixture should be deterministic and cheap. Prefer explicit stabilizer
  vector construction over generators or random search.
- Verify the expected distance and a small published/standard invariant that
  can be checked with the existing `cliff_*` surface. If a full published
  weight-enumerator parity check is not supportable without new runtime API,
  document the exact missing API and keep the fixture to the strongest
  available deterministic invariant.
- Update `clifford_limitations()` and `docs/rfcs/v1_PUNCHLIST.md` to separate
  what is now covered from what remains open.

Stop condition:

- If the existing public Clifford API cannot express the rotated d=3 code
  without new C runtime ABI or compiler work, do not fake it. Commit a finding
  under `findings/inbox/` that lists the exact missing API and the smallest next
  code change needed.

Validation:

```powershell
.\bin\nucleor.exe build tests\features\qm7_clifford_surface_d3_smoke.nr -o target\_qm7_surface_d3 --no-cache
.\target\_qm7_surface_d3.exe
bash tools/verify.sh --sequential-fixtures --only "test features/qm7_clifford_surface_d3_smoke"
bash tools/verify.sh --sequential-fixtures --only "test features/qm7_clifford_distance_5qubit_smoke"
bash tools/verify.sh --sequential-fixtures --only "test features/qm7_clifford_reset_rebuild_smoke"
git diff --check
```

### Scope F: QM-7 weight-enumerator closure probe

Only do this after Scope E is green or after filing the Scope E blocker
finding.

Required work:

- Determine whether current `cliff_*` APIs can compute or verify the published
  small-code weight-enumerator invariant without adding runtime ABI.
- If yes, add a focused deterministic fixture:
  `tests/features/qm7_clifford_weight_enumerator_smoke.nr`.
- If no, add a finding that specifies:
  - which current APIs were checked,
  - why they are insufficient,
  - the smallest stdlib/runtime surface needed next,
  - the expected validation command once that API exists.

Validation if a fixture is added:

```powershell
.\bin\nucleor.exe build tests\features\qm7_clifford_weight_enumerator_smoke.nr -o target\_qm7_weight_enum --no-cache
.\target\_qm7_weight_enum.exe
bash tools/verify.sh --sequential-fixtures --only "test features/qm7_clifford_weight_enumerator_smoke"
git diff --check
```

## Deliverable For Continuation Queue 2

Commit and push the branch. Add a new report under `findings/inbox/`, for
example:

`findings/inbox/helper1_r11_qsim_qm7_closure_v0829_2026-05-06.md`

Report branch, commit, merge-base with `origin/main`, exact files changed,
validation output, which Scopes D/E/F were completed, and the remaining quantum
gap list. Full verify and perf gate are not required for stdlib/test/docs-only
work, but do not leave a failing focused fixture behind.

## Append-Only Continuation Queue 3 (2026-05-06)

Keep going from this same document after Queue 2. This queue is intentionally
larger so you are not blocked waiting for one more tiny assignment. Work top-down
and batch adjacent scopes that stay stdlib/tests/docs/report-only. Stop at the
last green commit and write a finding if the next scope requires compiler
edits, C runtime ABI changes, thread-safety primitives, `bin/`, `bootstrap/`,
normal verify/perf wiring, or new Python helpers.

### Scope G: QM-8/QM-9 qsim graph query ergonomics review

Goal: determine whether adopters can inspect the auto-recorded graph without
dropping to raw C/runtime internals.

Required work:

- Inventory public qsim_graph query helpers:
  `qsim_gate_dag_size`, `qsim_gate_dag_depends_on`,
  `qsim_gate_dag_parent_count`, `qsim_gate_dag_parent_at`,
  status/preflight helpers, and limitations text.
- Add a focused fixture only if it covers a real missing query combination.
  Preferred name:
  `tests/features/qsim_graph_query_contract_smoke.nr`.
- The fixture should verify parent-count and dependency behavior after a mixed
  high-level sequence: H or other single-gate record if available, CNOT, CZ,
  CRK, SWAP, clear/rebuild.
- If no code change is needed, add a findings report section that says the
  query contract is already covered and names the fixtures proving it.
- Update `docs/rfcs/v1_PUNCHLIST.md` only if the status becomes materially more
  closed.

Validation:

```powershell
.\bin\nucleor.exe build tests\features\qsim_graph_query_contract_smoke.nr -o target\_qsim_graph_query --no-cache
.\target\_qsim_graph_query.exe
bash tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_query_contract_smoke"
git diff --check
```

### Scope H: QM-7 Clifford limitations/status coherence sweep

Goal: make sure the Clifford/QM-7 shipped status is not stale after any Scope E/F
work.

Required work:

- Review `stdlib/rods/clifford.nr`, all `qm7_clifford_*` fixtures,
  `clifford_disclosure_smoke.nr`, and `docs/rfcs/v1_PUNCHLIST.md`.
- Ensure `clifford_limitations()` names exactly what is covered and what remains
  open.
- If wording changes, update or add a disclosure fixture so the docs string does
  not drift silently.
- Do not broaden into runtime ABI or new Clifford algorithms unless already
  required and tiny.

Validation:

```powershell
.\bin\nucleor.exe build tests\features\clifford_disclosure_smoke.nr -o target\_clifford_disclosure --no-cache
.\target\_clifford_disclosure.exe
bash tools/verify.sh --sequential-fixtures --only "test features/clifford_disclosure_smoke"
git diff --check
```

### Scope I: Quantum/qsim release evidence matrix

Goal: leave a compact release-review matrix for the whole current quantum lane.

Required work:

- In the report, create a matrix covering:
  - QM-7 Bell/GHZ;
  - gate identities;
  - [[5,1,3]] distance;
  - reset/rebuild;
  - rotated d=3 surface-code status;
  - weight-enumerator status;
  - qsim graph status codes;
  - qsim checked record;
  - auto-entangle;
  - auto-record;
  - lifecycle/clear behavior;
  - query contract.
- Each row must include fixture path, command run, pass/fail/blocker, and
  remaining gap.
- Update `docs/rfcs/v1_PUNCHLIST.md` only when a row genuinely changes status.

Validation:

```powershell
git diff --check
```

### Scope J: Quantum next-code-surface blocker table

Goal: identify the smallest remaining code changes for the next mainline pass.

Required work:

- Add a blocker table to the report for any remaining QM-7/QM-8/QM-9 gaps:
  - blocker id;
  - exact missing API or invariant;
  - file(s) likely needing edits;
  - whether compiler/runtime ABI is required;
  - focused validation command after implementation.
- Include thread-safety only as a blocker/finding unless you can solve it
  without runtime ABI or locking primitives.
- Do not implement the blockers in this scope.

Validation:

```powershell
git diff --check
```

## Helper1 Deliverable For Queue 3

Commit and push one branch containing as many of Scopes G-J as stay cleanly
stdlib/tests/docs/report-only. Report which scopes completed, exact validation,
branch, commit, merge-base, files changed, and residual quantum blockers. Full
verify/perf is not required unless normal gates or compiler files change.

## Continuation Queue 4: QM-6/QM-3/QM-12 MPS and quantum-capacity closure pack

Appended 2026-05-06 by main agent. Continue using this same assignment
document as the source of truth. Take a big, clean chunk, but do not fake
coverage: if an item needs C runtime ABI or compiler work, file the blocker
with exact missing APIs and keep moving through the rest of the queue.

Base rules:

- Fetch first and branch from current `origin/main` unless the main agent tells
  you to rebase a live branch.
- Do not add new Python helpers.
- Keep code changes scoped to stdlib rods, feature fixtures, docs, and findings
  unless a tiny runtime/header edit is unavoidable and clearly validated.
- Do not overlap with Helper2's rust-bridge / POSIX harness lane.

### Scope K: QM-6 MPS Bell-correctness closure

Goal: move MPS coverage beyond allocation-only smoke if the current public API
already supports it.

Required work:

- Inspect `stdlib/rods/mps.nr`, MPS runtime declarations, and existing
  `mps_smoke` fixtures.
- If the existing public API can apply gates and inspect probabilities or
  statevector data, add a focused Bell-state correctness fixture.
- If the API cannot inspect correctness yet, do not invent a fake assertion.
  Add a blocker finding listing the exact missing rod/runtime functions and the
  smallest validation fixture that would close QM-6 once they exist.
- Update `docs/rfcs/v1_PUNCHLIST.md` and the quantum gap analysis only if the
  status genuinely changes.

Validation:

```powershell
.\bin\nucleor.exe build tests\features\<new_mps_fixture>.nr -o target\_mps_qm6 --no-cache
.\target\_mps_qm6.exe
git diff --check
```

### Scope L: QM-3 MPS named gate wrapper closure

Goal: remove raw-integer gate enum exposure where this can be done as
stdlib-only wrappers.

Required work:

- Add named MPS gate wrappers only if they can be implemented over existing
  public externs without ABI churn.
- Cover H, X, and CNOT first; include any existing enum constants in one shared
  location if the codebase pattern supports it.
- Add one focused fixture that calls the named wrappers and proves they reach
  the existing MPS path.
- If ABI work is needed, record the exact blocker instead of editing C broadly.

Validation:

```powershell
.\bin\nucleor.exe build tests\features\<new_mps_named_gate_fixture>.nr -o target\_mps_named_gates --no-cache
.\target\_mps_named_gates.exe
git diff --check
```

### Scope M: QM-12 shared quantum gate constants audit/closure

Goal: prevent diff_sim and MPS gate-type enum drift.

Required work:

- Inventory gate-type constants/enums in `quantum.nr`, `mps.nr`,
  `diff_sim.nr`, and related docs/tests.
- If a shared stdlib constant surface can be added without runtime ABI changes,
  add it and migrate at least one MPS and one diff_sim fixture or wrapper.
- If migration would be broad or ABI-dependent, add a precise blocker table in
  the report: constant name, current values, files that would change, and
  validation command.

Validation:

```powershell
rg -n "gate_type|MPS_GATE|DIFF|CNOT|H_GATE|X_GATE" stdlib tests docs
git diff --check
```

### Scope N: Quantum capacity/status disclosure pack

Goal: make remaining capacity limits explicit and test-backed where practical.

Required work:

- Review QM-2, QM-9, QM-11, and QM-14 limits:
  statevector tracker cap, qsim gate-DAG cap, diff_sim cap, logical-qubit
  registry cap.
- Add or tighten disclosure fixtures when strings already exist.
- Add small public status helpers only if they are stdlib-only and do not
  change runtime ABI.
- Leave thread-safety and runtime locking as blockers unless a tiny existing
  primitive makes the fix obvious.

Validation:

```powershell
.\bin\nucleor.exe build tests\features\<new_disclosure_fixture>.nr -o target\_quantum_caps --no-cache
.\target\_quantum_caps.exe
git diff --check
```

### Scope O: Quantum release-doc synchronization sweep

Goal: prevent the stale-advisory problem from recurring.

Required work:

- Cross-check `docs/rfcs/v1_PUNCHLIST.md`,
  `docs/rfcs/gap-analyses/Nucleor_Quantum_Subsystem_Gap_Analysis_and_RFC_2026-05-04.md`,
  `docs/rfcs/gap-analyses/README.md`, `docs/graph-capabilities.md`, and any
  rod limitation strings touched by Scopes K-N.
- Only update status claims backed by fixtures or blocker findings.
- Add a compact report section listing each remaining quantum blocker and the
  exact file/function surface needed next.

Validation:

```powershell
rg -n "QM-3|QM-6|QM-12|MPS|weight-enumerator|surface-code|gate-DAG|thread-safe" docs stdlib tests
git diff --check
```

## Helper1 Deliverable For Queue 4

Commit and push one branch containing as many of Scopes K-O as stay cleanly
stdlib/tests/docs/report-only. Report completed scopes, skipped scopes with
specific blockers, exact validation, branch, commit, merge-base, files changed,
and the remaining quantum blocker table. Full verify/perf is not required
unless compiler files, normal gate scripts, or generated manifests change.

## Continuation Queue 5: QM-2/QM-11/QM-13/QM-14 quantum-capacity closure pack

Append-only update, 2026-05-06. Queue 4 has landed from the helper branch
reported by the operator. Continue from a fresh base; do not reuse the old
helper base.

Branch setup:

```powershell
git fetch origin
git switch -c fix/helper1-r11-quantum-capacity-closure-v0830 origin/main
git merge-base HEAD origin/main
```

Hard constraints:

- Keep this as stdlib/tests/docs/report work unless a tiny compiler/runtime
  fix is unavoidable and clearly isolated.
- Do not add Python helpers or Python toolchain dependencies.
- If an ABI/runtime surface is missing, file a blocker with exact symbol names
  and continue to the next independent scope.
- Keep generated artifacts, promoted binaries, bootstrap seeds, and global
  manifests untouched unless explicitly redirected.
- Watch compile-time/RSS impact. Prefer tiny fixtures and direct wrappers over
  broad feature harnesses.

### Scope P: QM-2 statevector capacity/status closure

Goal: make statevector capacity failure behavior explicit and fixture-backed.

Required work:

- Locate statevector/qubit-capacity behavior across `stdlib/rods/quantum.nr`,
  tests, and docs.
- Add public status/preflight helpers only if they can be implemented in
  stdlib without runtime ABI changes.
- Add a focused feature fixture proving in-range and over-cap behavior.
- If the runtime only exposes string diagnostics and no status surface, add a
  blocker table instead of inventing fake status.

Validation:

```powershell
.\bin\nucleor.exe build tests\features\<new_statevector_capacity_fixture>.nr -o target\_qm2_statevector_capacity --no-cache
.\target\_qm2_statevector_capacity.exe
git diff --check
```

### Scope Q: QM-11 diff_sim capacity/status closure

Goal: make differentiable-simulation cap behavior queryable or at least
release-visible.

Required work:

- Review `stdlib/rods/diff_sim.nr`, related native bindings, fixtures, and
  gap-analysis docs.
- Add low-risk status wrappers or disclosure fixtures when existing symbols
  make that possible.
- If cap/error signals only exist as native-side behavior, document the exact
  missing ABI and smallest wrapper needed.

Validation:

```powershell
rg -n "diff_sim|DIFF|capacity|cap|status|qubit" stdlib tests docs
.\bin\nucleor.exe build tests\features\<new_diff_sim_capacity_fixture>.nr -o target\_qm11_diff_sim_capacity --no-cache
.\target\_qm11_diff_sim_capacity.exe
git diff --check
```

### Scope R: QM-13 pulse-level schedule overlap preflight

Goal: close the smallest pulse-schedule safety gap that can be proven without
new runtime locks.

Required work:

- Inventory pulse/schedule APIs and any existing overlap or timing validation.
- Add a stdlib-only preflight helper if current data structures already expose
  enough information.
- Add a fixture for a valid schedule and an overlapping/invalid schedule.
- If schedule internals are not inspectable from stdlib, file a precise
  blocker listing the structs/functions that must be exposed.

Validation:

```powershell
rg -n "pulse|schedule|overlap|duration|quantum" stdlib tests docs
.\bin\nucleor.exe build tests\features\<new_pulse_schedule_fixture>.nr -o target\_qm13_pulse_schedule --no-cache
.\target\_qm13_pulse_schedule.exe
git diff --check
```

### Scope S: QM-14 logical-qubit registry disclosure

Goal: turn the logical-qubit registry limit into a clear public contract.

Required work:

- Locate logical-qubit registry state, constants, and current tests/docs.
- Add named constants or status helpers if they are already representable in
  stdlib.
- Add a focused disclosure fixture, or a blocker table if the limit is only
  native/internal.
- Avoid broad logical-code refactors.

Validation:

```powershell
rg -n "logical|registry|qubit|capacity|status" stdlib tests docs
.\bin\nucleor.exe build tests\features\<new_logical_registry_fixture>.nr -o target\_qm14_logical_registry --no-cache
.\target\_qm14_logical_registry.exe
git diff --check
```

### Scope T: quantum remaining-blocker compression

Goal: reduce the quantum punchlist to a short, evidence-backed final queue.

Required work:

- Update `docs/rfcs/v1_PUNCHLIST.md` and quantum gap-analysis docs only for
  claims backed by this queue's fixtures or blocker reports.
- Produce a compact remaining-blocker matrix covering QM-2, QM-11, QM-13,
  QM-14, and any leftovers from QM-3/QM-6/QM-12.
- For every blocker include exact file/function surface, validation command,
  and whether helper/main should own the next slice.

Validation:

```powershell
rg -n "QM-2|QM-3|QM-6|QM-11|QM-12|QM-13|QM-14" docs stdlib tests
git diff --check
```

## Helper1 Deliverable For Queue 5

Commit and push one branch containing as many Scopes P-T as stay cleanly
stdlib/tests/docs/report-only. Report completed scopes, skipped scopes with
exact blockers, validation output, branch, commit, merge-base, and files
changed. Full verify/perf is not required unless compiler/runtime/gate scripts
or generated manifests change.

---

## Queue 6 Addendum - QM-7 closure plus robotics fixture lane

Append-only update: 2026-05-06.

Base rule:

- If the operator has promoted the integration batch to `origin/main`, branch
  fresh from current `origin/main`.
- Otherwise branch fresh from
  `origin/fix/main-qm7-surface-code-v0827`.
- Do not base from the local Claude spike. Main owns that integration.
- You are not alone in the repo. Do not revert or overwrite edits by other
  agents. Keep this branch focused on quantum/robotics stdlib, runtime, tests,
  docs, and your report.

Performance rule:

- Keep fixtures tiny and deterministic. Avoid broad stress loops unless they are
  bounded by an obvious small constant.
- If you touch runtime C or compiler-adjacent surfaces, run focused build/run,
  `git diff --check`, and the smallest relevant `tools/verify.sh --only ...`
  slice. Full verify/perf is not required from helper unless your branch changes
  gate scripts, compiler source, promoted binaries, or generated manifests.

### Scope U: QM-7 Clifford weight-enumerator feasibility and closure

Goal: close or sharply reduce the remaining QM-7 Phase 2 blocker:
published weight-enumerator parity.

Required work:

- Inspect `stdlib/runtime/clifford_rt.c`, `stdlib/rods/clifford.nr`, current
  Clifford fixtures, and the quantum gap docs.
- Determine whether current runtime internals already have enough machinery to
  count Pauli/stabilizer/logical operators by weight without adding a broad
  simulator rewrite.
- If clean, add a bounded public API for weight counts/enumerator buckets. Keep
  the API narrow and explicit about caps.
- Add a focused fixture for the existing Surface-17 d=3 code and, if reliable
  values are available in the existing docs/fixture comments, assert the known
  published parity. If exact published enumerator values are not already
  available locally, do not invent them: add an internal exhaustive consistency
  fixture plus a blocker table naming the missing citation/value.
- Update `docs/rfcs/v1_PUNCHLIST.md` and the quantum gap doc only for claims
  backed by the new fixture or blocker.

Suggested validation when implemented:

```powershell
rg -n "clifford|weight|enumerator|surface|stabilizer|logical" stdlib tests docs
.\bin\nucleor.exe build tests\features\<new_clifford_weight_fixture>.nr -o target\_qm7_weight_enum --no-cache
.\target\_qm7_weight_enum.exe
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/<new_clifford_weight_fixture>" | tail -n 12; exit ${PIPESTATUS[0]}'
git diff --check
```

### Scope V: QM-7 bounded Clifford property micro-suite

Goal: add deterministic breadth without randomized flake or large runtime cost.

Required work:

- Add one small Clifford fixture that checks invariants across a bounded set of
  known small codes/gate sequences:
  - reset/rebuild remains stable;
  - distance stays positive for known code handles;
  - detectable single-qubit Pauli counts remain stable;
  - logical operators remain non-detectable where fixtures already define them.
- Reuse existing helpers and constants. Do not introduce a random generator.
- If Scope U lands an enumerator API, include one small cross-check against it.

Suggested validation:

```powershell
.\bin\nucleor.exe build tests\features\<new_clifford_property_fixture>.nr -o target\_qm7_property --no-cache
.\target\_qm7_property.exe
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/<new_clifford_property_fixture>" | tail -n 12; exit ${PIPESTATUS[0]}'
git diff --check
```

### Scope W: ROBO-14 end-to-end robotics fixture feasibility

Goal: see whether the existing robotics rods can support a small
IK -> plan -> smooth -> time-parameterize -> FK endpoint smoke without compiler
changes.

Required work:

- Inventory `stdlib/rods` robotics surfaces for IK, RRT/PRM/planning, CHOMP,
  TOPP/trajectory, FK/kinematics, and any existing examples/tests.
- If clean, add one deterministic feature fixture that exercises the smallest
  end-to-end chain and asserts final endpoint tolerance or a clear status code.
- If the chain cannot be built from current public APIs, write a blocker table
  naming exact missing rods/functions and the smallest API needed.
- Keep ROBO-7 frame-typing enforcement out of this scope unless it is purely a
  doc/fixture disclosure; compiler-side frame checking is main-owned.

Suggested validation:

```powershell
rg -n "ik|rrt|prm|chomp|topp|trajectory|fk|kinematics|pose|frame" stdlib tests docs
.\bin\nucleor.exe build tests\features\<new_robo14_fixture>.nr -o target\_robo14_chain --no-cache
.\target\_robo14_chain.exe
git diff --check
```

### Scope X: ROBO-7 frame-safety disclosure lock

Goal: make the current advisory-only frame marker state impossible to
mis-market while main prepares compiler enforcement.

Required work:

- Confirm current frame marker surfaces and compiler disclosure text.
- Add or update a tiny fixture/doc note proving markers parse and run but do
  not yet enforce mismatches at compile time.
- Do not implement compiler frame checking here.

Suggested validation:

```powershell
rg -n "ROBO-7|frame|kinematics_frame|TYP-008|Mars" docs compiler stdlib tests
.\bin\nucleor.exe build tests\features\<new_frame_disclosure_fixture>.nr -o target\_robo7_frame_disclosure --no-cache
git diff --check
```

### Scope Y: quantum/robotics final blocker compression

Goal: leave a concise remaining queue for main.

Required work:

- Update your report with a matrix covering:
  - QM-7 weight enumerator;
  - QM-7 property breadth;
  - QM-6 joint probability/statevector extraction;
  - qsim/diff_sim raw escape hatches;
  - qsim graph thread safety;
  - ROBO-7 frame enforcement;
  - ROBO-14 end-to-end robotics smoke.
- For each row include exact file/function surface, blocker or branch status,
  validation command, and owner suggestion.

### Scope Z: QM-6 MPS joint-probability / statevector extraction

Goal: continue the `mps_prob0` work into the remaining QM-6 gap: a small,
bounded API for MPS joint probability or statevector-style readout.

This scope is approved for Helper1 if it stays in the quantum runtime/stdlib/
tests/docs lane. It is preferable to stacking compiler effect-row work on the
same branch.

Required work:

- Inspect `stdlib/runtime/mps_rt.c`, `stdlib/rods/mps.nr`, existing MPS/qsim
  fixtures, and the QM-6 blocker in your report.
- Determine the smallest readout surface that can be implemented safely:
  - preferred: bounded joint probability for a small bitstring / basis state;
  - acceptable: bounded statevector amplitude/probability extraction for small
    `n`;
  - fallback: exact blocker if MPS internals make this unsafe without a larger
    tensor contraction API.
- Keep caps explicit. Do not add an unbounded full-state dump path.
- Add a focused fixture comparing MPS readout against the existing qsim
  reference on Bell and one small non-entangled/control case.
- Update `docs/rfcs/v1_PUNCHLIST.md`, the quantum gap doc, and your report
  only for behavior proven by the fixture.

Do not take these in this scope:

- QM-2/QM-11 raw native fail-closed policy changes;
- QM-12 typed rotation dispatch policy;
- QM-13 backend/resource scheduler design;
- R05/EFF compiler enforcement.

Suggested validation:

```powershell
rg -n "mps|prob|statevector|amplitude|qsim|Bell" stdlib tests docs
.\bin\nucleor.exe build tests\features\<new_mps_joint_readout_fixture>.nr -o target\_qm6_mps_joint_readout --no-cache
.\target\_qm6_mps_joint_readout.exe
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/<new_mps_joint_readout_fixture>" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/mps_bell_probabilities_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
git diff --check
```

## Helper1 Deliverable For Queue 6

Commit and push one branch containing as many Scopes U-Z as stay coherent.
Report completed scopes, skipped scopes with exact blockers, validation output,
branch, commit, merge-base, and files changed. Prefer one substantial branch
over tiny nibble branches.

## Queue 7 Addendum - Current Quantum Residual + Robotics Closure Batch

Append-only update, 2026-05-06.

Read this before continuing. Several older Queue 6 items have since landed on
the integration branch. Do not redo closed work. Base from current integration:

```powershell
git fetch origin
git checkout -B fix/helper1-quantum-robotics-residuals-v0835 origin/fix/main-qm7-surface-code-v0827
git merge-base HEAD origin/fix/main-qm7-surface-code-v0827
```

Current closed quantum surfaces to avoid redoing:

- QM-6 MPS Bell/joint-probability/statevector capped extraction is documented
  as closed in `docs/rfcs/v1_PUNCHLIST.md`.
- QM-2 qsim checked init and QM-11 diff_sim checked init are documented closed.
- R11-D4 qsim auto-entangle, auto-record, lifecycle, and query contract are
  documented closed except for graph thread-safety.
- QM-12 common H/CNOT/X/Z gate constants are documented closed; rotation IDs
  remain open.
- QM-13 schedule overlap/checked insertion and QM-14 logical-qubit registry cap
  are documented closed.

### Scope AA: QM-7 published weight-enumerator closure

Goal: close the remaining QM-7 Phase 2 blocker if current Clifford surfaces can
support a bounded published weight-enumerator parity check.

Required work:

- Inspect:
  - `stdlib/rods/clifford*.nr`;
  - existing `qm7_*` fixtures;
  - `docs/rfcs/v1_PUNCHLIST.md`;
  - `docs/rfcs/gap-analyses/Nucleor_Quantum_Subsystem_Gap_Analysis_and_RFC_2026-05-04.md`.
- Determine whether the public Clifford/stabilizer APIs can enumerate or count
  stabilizer/logical operators by weight for the published d=3 surface case.
- If clean, add a bounded public API and one focused fixture. Keep caps small
  and deterministic.
- If not clean, write the exact blocker: missing function names, missing data
  shape, and smallest safe API to add next. Do not fabricate parity with a
  fixture that only checks existing distance/detectability wrappers.

Suggested validation:

```powershell
rg -n "clifford|weight|enumerator|surface|stabilizer|logical|QM-7" stdlib tests docs
.\bin\nucleor.exe build tests\features\<new_qm7_weight_fixture>.nr -o target\_qm7_weight_enum --no-cache
.\target\_qm7_weight_enum.exe
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/<new_qm7_weight_fixture>" | tail -n 12; exit ${PIPESTATUS[0]}'
git diff --check
```

### Scope AB: QM-6 high-qubit MPS streaming/external-sink extraction

Goal: reduce the remaining QM-6 gap without adding an unbounded full-state dump.

Required work:

- Inspect `stdlib/rods/mps.nr`, `stdlib/runtime/mps_rt.c`, and current
  statevector cap helpers.
- Add either:
  - a small streaming/external-sink design note plus fail-closed public cap
    fixture; or
  - a first bounded API that emits probabilities/amplitudes through a caller
    supplied cap/range without materializing `2^n` values.
- Keep memory caps explicit and testable.
- Do not raise `mps_statevector_max_qubits()` to hide the issue.

Suggested validation:

```powershell
rg -n "mps_statevector|max_qubits|prob_basis|amplitude|stream|sink|cap" stdlib tests docs
.\bin\nucleor.exe build tests\features\<new_mps_stream_fixture>.nr -o target\_qm6_mps_stream --no-cache
.\target\_qm6_mps_stream.exe
git diff --check
```

### Scope AC: qsim graph thread-safety disclosure or first guard

Goal: make the remaining process-local qsim graph limitation explicit and, if
small, fail-closed for obvious concurrent misuse.

Required work:

- Inspect `stdlib/rods/qsim_graph.nr`, `stdlib/runtime/qsim_graph_rt.c`, and
  qsim graph fixtures.
- Determine whether the graph state is process-local/global and whether any
  current public API claims thread safety.
- If a small guard exists using current runtime primitives, add it and fixture
  the fail-closed status.
- If not, update docs/report with a clear limitation and the smallest runtime
  primitive needed. Do not add broad pthread/async infrastructure in this
  branch.

Suggested validation:

```powershell
rg -n "qsim_graph|thread|pthread|mutex|atomic|process-local|gate_dag" stdlib tests docs
.\bin\nucleor.exe build tests\features\<new_qsim_graph_thread_fixture>.nr -o target\_qsim_graph_thread --no-cache
git diff --check
```

### Scope AD: QM-12 typed rotation ID unification

Goal: close or sharply reduce the remaining rotation-ID drift across MPS and
diff_sim without changing native dispatch policy blindly.

Required work:

- Inspect `stdlib/rods/quantum_gates.nr`, `stdlib/rods/mps.nr`,
  `stdlib/rods/diff_sim.nr`, and current gate-constant fixtures.
- Add shared typed constants/wrappers for rotations only if they can preserve
  existing runtime ABI behavior.
- If MPS and diff_sim genuinely use incompatible native IDs, write a blocker
  naming the exact translation layer required instead of forcing one enum.
- Add a focused fixture for whatever is proven.

Suggested validation:

```powershell
rg -n "RZ|RX|RY|rotation|gate_id|quantum_gate|MPS|diff_sim" stdlib tests docs
.\bin\nucleor.exe build tests\features\<new_rotation_fixture>.nr -o target\_qm12_rotation_ids --no-cache
.\target\_qm12_rotation_ids.exe
git diff --check
```

### Scope AE: ROBO-14 end-to-end robotics smoke or blocker

Goal: use current public robotics rods to prove one small deterministic
IK/planning/trajectory/kinematics path, or leave an exact missing-surface table.

Required work:

- Inventory public robotics rods and fixtures for IK, planning, smoothing,
  trajectory, FK, pose, and frame markers.
- If the chain exists, add one deterministic feature fixture with a tolerance or
  status assertion.
- If the chain cannot be expressed, report the exact missing public functions.
- Keep ROBO-7 compiler frame enforcement out of this branch; only disclose
  current advisory marker behavior if touched.

Suggested validation:

```powershell
rg -n "ik|rrt|prm|chomp|topp|trajectory|fk|kinematics|pose|frame|robot" stdlib tests docs
.\bin\nucleor.exe build tests\features\<new_robo14_fixture>.nr -o target\_robo14_chain --no-cache
.\target\_robo14_chain.exe
git diff --check
```

### Scope AF: quantum/robotics residual ledger v0835

Goal: leave main a concise residual ledger after Scopes AA-AE.

Output:

```text
findings/inbox/helper1_quantum_robotics_residuals_v0835_2026-05-06.md
```

Required rows:

- QM-7 weight enumerator;
- QM-6 high-qubit MPS streaming/external sink;
- qsim graph thread safety;
- QM-12 typed rotations;
- ROBO-14 end-to-end smoke;
- ROBO-7 compiler frame enforcement disclosure.

For each row include current status, changed files, validation command, exact
remaining blocker if any, and owner recommendation.

## Helper1 Deliverable For Queue 7

Push one branch with as many Scopes AA-AF as stay coherent. Prefer a substantial
stdlib/runtime/tests/docs branch over tiny slices, but stop at exact blockers
where runtime ABI or compiler enforcement would be required.

Final handoff must include:

```text
Branch:
HEAD:
Base:
Merge-base:
Completed scopes:
Skipped scopes and exact blockers:
Changed files:
Validation:
Report paths:
Whether main needs drift/self-host/perf/full verify:
```

Do not touch compiler, tool gates, `bin/`, or `bootstrap/` unless the branch is
explicitly redirected. Full verify/perf is not required for stdlib/test/doc-only
work; run focused build/run and focused `verify.sh --only` for each fixture.

---

## Queue 8 Addendum - RT Determinism and Algebraic Laws Closure Batch

Append-only update, 2026-05-06. Quantum/robotics Queue 7 is no longer active
for helper1 unless main explicitly reopens it. Continue with this Windows-safe
compiler trust batch. Do not work PKG-1 or R06 native Linux evidence; cloud
Codex owns those on `fix/helper2-native-linux-pkg-r06-closure-v0837`.

Start fresh:

```powershell
git fetch origin --prune
git checkout -B fix/helper1-rt-laws-closure-v0838 origin/main
git status --short --branch
git merge-base HEAD origin/main
```

Expected assignment-time base:

```text
origin/main: 9448f335178cb7ecac9b3b7700e132c9c80507e8
```

If `origin/main` has advanced, use current `origin/main` and record the actual
base.

### Scope AG: RT transitive same-file enforcement

Goal: advance RT determinism beyond direct same-file helper calls without
waiting on parser/tools-suite unification.

Primary target:

```text
compiler/nucleor_s1_compiler.nr
tests/err/err_no_alloc*.nr
tests/err/err_no_panic*.nr
docs/rfcs/Nucleor_Error_Codes.md
docs/rfcs/v1_PUNCHLIST.md
findings/inbox/helper1_rt_transitive_closure_v0838_2026-05-06.md
```

Required work:

- Inspect current `#[no_alloc]` and `#[no_panic]` checks and document the exact
  traversal boundary already implemented.
- Add a bounded same-file transitive check for one additional call depth if it
  can be done without a broad whole-program traversal.
- Add focused negative fixtures:
  - `#[no_alloc]` caller -> helper -> allocator;
  - `#[no_panic]` caller -> helper -> panic/known panic helper.
- Add a positive fixture proving clean helper chains still compile.
- If recursion, function pointers, closures, or cross-module calls make the
  traversal unsafe, fail closed or write an exact blocker; do not overclaim.

Validation:

```bash
bash tools/verify.sh --only "<focused no_alloc/no_panic step>"
bash tools/check_compiler_drift.sh
git diff --check
```

Run the perf gate if you add a traversal over many functions or compiler
hot-path state.

### Scope AH: RT deadline/WCET fail-closed audit

Goal: convert `#[deadline]` from ambiguous trust surface into an explicit
current-state contract.

Required work:

- Inspect `#[deadline]` parsing and diagnostics.
- If there is no numeric/WCET enforcement, add or improve fail-closed
  diagnostic coverage so adopters cannot treat `#[deadline]` as proven.
- Add one focused fixture for the current contract.
- Update `docs/rfcs/v1_PUNCHLIST.md` and error-code docs only if diagnostics
  change.

If true WCET backing would require a larger pass or cost model, write the
blocker with exact source paths and do not attempt a speculative implementation.

### Scope AI: Algebraic laws Phase 3b bounded-property expansion

Goal: advance laws without touching parser/tools-suite. Prefer one coherent,
testable expansion over a broad rewrite engine.

Primary target:

```text
compiler/nucleor_s1_compiler.nr
tests/features/law_*_smoke.nr
tests/err/err_law*.nr
docs/rfcs/RFC-0031-algebraic-laws.md
docs/rfcs/v1_PUNCHLIST.md
findings/inbox/helper1_law_phase3b_v0838_2026-05-06.md
```

Required work:

- Inspect existing `nuc test --check-laws` forms.
- Add one non-float bounded property expansion if the schema already supports
  it cleanly, for example `inverse`, `distributive_over`, or another low-risk
  declared law shape.
- Add fail-closed diagnostics for unsupported or float-sensitive law forms
  instead of silently accepting them.
- Do not enable optimizer rewrites from laws unless the verification metadata
  gate is already proven in the same branch.

Validation:

```bash
bash tools/verify.sh --only "CLI: nuc test --check-laws validates laws and schema"
bash tools/check_compiler_drift.sh
git diff --check
```

Run perf gate if compiler traversal or optimizer behavior changes materially.

### Scope AJ: RT/laws residual ledger

Create:

```text
findings/inbox/helper1_rt_laws_residual_ledger_v0838_2026-05-06.md
```

Rows:

- RT transitive same-file checks;
- RT cross-module checks;
- RT fn-pointer/closure dispatch;
- deadline/WCET backing;
- law bounded integer generation;
- law float approximate semantics;
- law optimizer rewrite gating.

For each row include status, files changed, validation, remaining blocker, and
recommended owner.

## Helper1 Deliverable For Queue 8

Push:

```text
fix/helper1-rt-laws-closure-v0838
```

Final handoff must include:

```text
Branch:
HEAD:
Base:
Merge-base:
Completed scopes:
Skipped scopes and exact blockers:
Changed files:
Validation:
Report paths:
Whether main needs drift/self-host/perf/full verify:
```

Do not run full verify by default. Use focused gates plus perf only when the
compiler hot path is materially changed.
