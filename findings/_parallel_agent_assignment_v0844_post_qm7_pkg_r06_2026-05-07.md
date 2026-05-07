# Parallel agent assignment v0844 - post QM7 / PKG-1 / R06 closure

Date: 2026-05-07
Base for every queue: current `origin/main`

This dispatch starts after these closures are on `main`:

- Helper3 T-4 numeric strict fixture wiring.
- QM-7 OpenQASM 2.0 minimal parser / round-trip fixture.
- PKG-1 native Linux signed publish proof.
- R06 POSIX rust_bridge ownership proof.
- RFC-0063 Wave 7 tools-suite duplicate retirement.

## Global rules

- Each agent must use its own isolated worktree or clone. Do not share a
  checkout with another agent.
- Start every queue with:

```powershell
git fetch origin
git checkout -B <branch-name> origin/main
git status --short --branch
git merge-base HEAD origin/main
```

- Do not stack Queue B on an unintegrated Queue A branch unless the assignment
  explicitly says to do so.
- No Python helpers in product/toolchain paths.
- Keep cold compiler perf tight. Any compiler-source lane must run
  `pwsh -NoProfile -File tools\check_perf_regression.ps1`.
- Do not edit `bin/` or `bootstrap/` unless compiler source changes and the
  queue explicitly requires rebuild/promote/self-host validation.
- Focused validation first. Do not run full verify unless the user asks for it.
- Every queue must write `findings/inbox/<agent>_<topic>_v0844_2026-05-07.md`
  with branch, HEAD, base, merge-base, changed files, exact validation, and
  residual blockers.

## Helper1 - R05 effects / capabilities closure

### Queue A - Standalone `requires [...]` enforcement

Branch:

```text
fix/helper1-r05-requires-row-enforcement-v0844
```

Goal:

- Close the current punchlist row that says standalone `requires [...]` row
  enforcement remains open.
- Implement real enforcement for same-file function bodies that declare
  `requires [...]`, matching the current `restricts [...]` and `with [...]`
  behavior where possible.
- Add positive and negative fixtures for direct calls, helper calls, clean
  functions, and row-compatible functions.

Primary files:

```text
compiler/nucleor_s1_compiler.nr
tests/err/err_requires_*.nr
tests/features/requires_*_smoke.nr
docs/rfcs/v1_PUNCHLIST.md
```

Validation:

```powershell
.\bin\nucleor.exe build tests\features\<new_positive>.nr -o _r05_requires_positive_v0844 --no-cache
.\target\_r05_requires_positive_v0844.exe
.\bin\nucleor.exe build tests\err\<new_negative>.nr -o _r05_requires_negative_v0844 --no-cache
bash tools/check_compiler_drift.sh
git diff --check
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

### Queue B - Transitive effects residual audit + safe extension

Branch:

```text
fix/helper1-r05-transitive-effects-residual-v0844
```

Start only after Queue A is pushed or explicitly blocked, from fresh
`origin/main`.

Goal:

- Extend same-file transitive `restricts` / `requires` checking beyond the
  currently documented shallow/depth-limited cases if it can be done without a
  large memory or cold-compile cost.
- If cross-module propagation needs a larger symbol-table change, do not fake
  it. File a precise blocker report and add the smallest safe diagnostic or
  fixture that proves the gap.

Validation: focused fixtures, `bash tools/check_compiler_drift.sh`,
`git diff --check`, and perf gate.

## Helper2 - RFC-0063 tools-suite dedup / perf headroom

### Queue A - Wave 8 remaining identical duplicate removal

Branch:

```text
fix/helper2-rfc0063-tools-suite-wave8-v0844
```

Goal:

- Continue RFC-0063 after Wave 7.
- Use `tools/audit_dup_fns.nr` / `tools/audit_dup_fns_report.csv` to remove or
  import the remaining `IDENTICAL` duplicate functions between
  `compiler/nucleor_s1_compiler.nr` and `compiler/nucleor_tools_suite.nr`.
- Preserve behavior; this queue is deletion/import only, not semantic rewrite.

Primary files:

```text
compiler/nucleor_s1_compiler.nr
compiler/nucleor_tools_suite.nr
compiler/nucleor_rfc0063_shared_wave1.nr
tools/audit_dup_fns_report.csv
docs/rfcs/RFC-0063-TOOLCHAIN-COMMONIZATION-ROADMAP.md
docs/rfcs/v1_PUNCHLIST.md
```

Validation:

```powershell
.\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o nucleor_tools --no-cache
.\bin\nucleor.exe build tools\audit_dup_fns.nr -o audit_dup_fns --no-cache
.\target\audit_dup_fns.exe
bash tools/check_compiler_drift.sh
bash tools/check_rod_void_abi.sh
git diff --check
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

### Queue B - Wave 9 body-diff triage and first safe bucket

Branch:

```text
fix/helper2-rfc0063-tools-suite-wave9-v0844
```

Start only after Queue A is integrated to `main` or explicitly approved to
stack.

Goal:

- Triage the `SIG_MATCH_BODY_DIFFERS` bucket into safe categories:
  formatting-only, diagnostics-text-only, tool-mode intentional drift,
  compiler-only behavior, and unsafe-to-share.
- Implement the first safe non-identical bucket only if it is mechanically
  clear and validation stays green.
- Otherwise produce a blocker report with the exact function list and a
  recommended Wave 9 implementation plan.

Validation: same as Queue A, including perf gate.

## Helper3 - UNIT-1 and T-3/T-4 strict tail

### Queue A - UNIT-1 semantic diagnostics pack

Branch:

```text
fix/helper3-unit1-semantic-diagnostics-v0844
```

Goal:

- Advance UNIT-1 beyond the current positive API partial.
- Add the next small compiler-backed unit diagnostics without destabilizing
  the parser: prioritize UNIT-001..005 style errors for obvious misuse paths
  already represented in docs/RFCs.
- Add positive smoke coverage for the existing `UnitDistance` /
  `UnitVelocity` API so diagnostics do not regress legitimate code.

Primary files:

```text
compiler/nucleor_s1_compiler.nr
stdlib/rods/units.nr
tests/err/err_unit_*.nr
tests/features/unit_*_smoke.nr
docs/rfcs/v1_PUNCHLIST.md
```

Validation:

```powershell
.\bin\nucleor.exe build tests\features\<unit_positive>.nr -o _unit_positive_v0844 --no-cache
.\target\_unit_positive_v0844.exe
bash tools/check_compiler_drift.sh
git diff --check
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

### Queue B - T-3 char distinctness / non-constant proof

Branch:

```text
fix/helper3-t3-char-distinctness-v0844
```

Start only after Queue A is pushed or explicitly blocked, from fresh
`origin/main`.

Goal:

- Close or sharply reduce the remaining T-3/T-4 tail: char distinctness and
  non-constant proof.
- Add fixtures that prove char values do not silently flow into integer-only
  helper paths and that non-constant expressions are checked strictly.
- Wire any new stable fixture into `tools/verify.sh` only after it is proven
  deterministic.

Validation: focused build/run, `bash tools/check_compiler_drift.sh`,
`git diff --check`, and perf gate if compiler code changes.

## Local Claude - ROBO-7 transform typing and RT determinism

### Queue A - ROBO-7 `Transform<From, To>` surface

Branch:

```text
fix/local-claude-robo7-transform-typing-v0844
```

Goal:

- Continue from the typed `Pose<F>` stdlib migration.
- Add a zero-cost `Transform<From, To>` facade and typed transform helpers
  that make camera-to-base / base-to-camera direction part of the type surface.
- Add FRAME-002/FRAME-003 style fixtures for wrong-direction transform use.
- Do not remove `Frame_Unknown`; keep migration compatibility unless the
  queue can prove all current fixtures remain green.

Primary files:

```text
stdlib/rods/kinematics.nr
stdlib/rods/kinematics_frame.nr
tests/features/robo7_*_smoke.nr
tests/err/err_robo7_*.nr
docs/rfcs/v1_PUNCHLIST.md
```

Validation:

```powershell
.\bin\nucleor.exe build tests\features\<robo7_positive>.nr -o _robo7_transform_v0844 --no-cache
.\target\_robo7_transform_v0844.exe
bash tools/check_rod_void_abi.sh
git diff --check
```

Run compiler drift/perf only if compiler code changes.

### Queue B - RT deadline syntax / deterministic diagnostic baseline

Branch:

```text
fix/local-claude-rt-deadline-diagnostic-v0844
```

Start only after Queue A is pushed or explicitly blocked, from fresh
`origin/main`.

Goal:

- Advance the RT punchlist without pretending to have full certified WCET.
- Add parser/type-checker recognition and deterministic diagnostics for
  malformed or unsupported `#[deadline(...)]` use, or document the exact
  compiler hook needed if the attribute path is not clean.
- Add positive no-op smoke for accepted syntax only if semantics remain honest.

Validation: focused fixtures, drift, diff check, and perf gate for compiler
changes.

## Optional cloud Linux lane - release prereq docs only

Use this only if another Linux cloud agent is available. Otherwise keep local
agents on the queues above.

Branch:

```text
fix/cloud-linux-release-prereq-docs-v0844
```

Goal:

- Convert the PKG-1/R06 proof prereqs into a short POSIX release operator doc:
  `pwsh`, `openssh-client`/`ssh-keygen`, clang, cargo/rustc where needed,
  native `bin/nucleor` bootstrap, and locally built `bin/nucleor_tools`.
- Add no product code and no scripts unless there is already an obvious docs
  index link to update.

Validation:

```bash
git diff --check
```

Deliverable:

```text
findings/inbox/cloud_linux_release_prereq_docs_v0844_2026-05-07.md
```
