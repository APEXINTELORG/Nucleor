# Helper3 assignment v0842 - Type / Units closure

Audience: local Codex Helper3
Base: fetch current `origin/main` before each queue
Mode: implementation, focused validation, push branch, write report

Do not reuse another helper's worktree. Do not edit Helper1/Helper2/Claude
lanes. No Python helpers.

## Queue 1 - UNIT-1 Positive Typed-Unit API Surface

Branch:

```text
fix/helper3-unit1-positive-api-v0842
```

Start:

```powershell
git fetch origin
git checkout -B fix/helper3-unit1-positive-api-v0842 origin/main
git status --short --branch
git merge-base HEAD origin/main
```

Goal:

- Move UNIT-1 beyond archive fail-closed guards by adding a small positive
  typed-unit API surface that builds and runs.
- Prefer library helpers and fixtures over compiler parser changes.

Primary files:

```text
stdlib/rods/units.nr
tests/err/err_unit_*.nr
docs/rfcs/v1_PUNCHLIST.md
docs/spec/Nucleor_Error_Codes.md
```

Preferred implementation:

- Add explicit constructors/accessors for one or two concrete dimensions
  already implied by the archive guard, for example distance and velocity.
- Add positive smoke coverage proving valid same-dimension construction,
  access, and arithmetic helper behavior.
- Keep the storage/lowering contract honest; do not claim full
  `unit<T, dim>` parser algebra unless implemented.

Candidate fixtures:

```text
tests/features/unit_distance_positive_smoke.nr
tests/features/unit_velocity_positive_smoke.nr
```

Boundaries:

- Do not change parser/type-checker dimension algebra in this queue unless a
  tiny local change is unavoidable.
- Do not touch R05, ROBO-7, RT, RFC-0063, Linux package/R06, `bin/`, or
  `bootstrap/`.
- No Python helpers.

Validation:

```powershell
.\bin\nucleor.exe build tests\features\unit_distance_positive_smoke.nr -o _unit_distance_positive_v0842 --no-cache
.\target\_unit_distance_positive_v0842.exe
bash tools/check_rod_void_abi.sh
git diff --check
```

Run all new fixtures. Run compiler drift only if compiler/tooling metadata
changes. Run perf only if compiler or hot toolchain code changes.

Deliverable:

```text
findings/inbox/helper3_unit1_positive_api_v0842_2026-05-07.md
```

## Queue 2 - T-3 / T-4 Strict Type Tail Pack

Start this only after Queue 1 is pushed or explicitly blocked. Fetch current
`origin/main` and start a fresh branch.

Branch:

```text
fix/helper3-t3-t4-strict-tail-v0842
```

Start:

```powershell
git fetch origin
git checkout -B fix/helper3-t3-t4-strict-tail-v0842 origin/main
git status --short --branch
git merge-base HEAD origin/main
```

Goal:

- Close another bounded T-3/T-4 type-system tail with real fixtures.
- Preferred order:
  1. T-4 strict helper return typing for the next uncovered helper family.
  2. T-3 char distinctness / non-constant char-cast guard if the first option
     is already closed or too small.

Primary files:

```text
compiler/nucleor_s1_compiler.nr
compiler/nucleor_tools_suite.nr
tests/features/t4_strict_*_rtypes.nr
tests/err/err_t3_invalid_char_cast.nr
docs/rfcs/v1_PUNCHLIST.md
docs/spec/Nucleor_Error_Codes.md
```

Preferred T-4 implementation:

- Audit strict inference helper-return tables in both compiler copies.
- Add missing scalar/string/Vec helper return types for one coherent helper
  family.
- Add a positive strict-mode fixture that would have failed before.

Candidate fixture:

```text
tests/features/t4_strict_remaining_helper_rtypes.nr
```

Validation:

```powershell
.\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _helper3_t4_s1_v0842 --no-link --no-cache
.\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o nucleor_tools --no-cache
bash tools/check_compiler_drift.sh
bash tools/check_rod_void_abi.sh
git diff --check
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

Deliverable:

```text
findings/inbox/helper3_t3_t4_strict_tail_v0842_2026-05-07.md
```

Include branch, HEAD, base, merge-base, implemented type surface, skipped
surfaces, changed files, validation, perf numbers if run, and whether main
needs self-host/full verify.
