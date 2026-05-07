# Helper3 UNIT-1 positive API closure v0842

## Branch / base

- Branch: `fix/helper3-unit1-positive-api-v0842`
- Start HEAD: `4fa86e027a08f5e83dbc6e931dd42e1234894a21`
- Base: `origin/main` at `4fa86e027a08f5e83dbc6e931dd42e1234894a21`
- Merge-base: `4fa86e027a08f5e83dbc6e931dd42e1234894a21`

## Implemented type surface

- Added nominal `UnitDistance` and `UnitVelocity` structs in `stdlib/rods/units.nr`.
- Added explicit distance constructors for meters, kilometers, centimeters, and millimeters.
- Added explicit velocity constructors for meters/second and kilometers/hour.
- Added read-only accessors for value and unit IDs.
- Added explicit conversion helpers:
  - `unit_distance_value_as`
  - `unit_velocity_value_mps`
  - `unit_velocity_value_as`
- Added same-dimension arithmetic helpers:
  - `unit_distance_add` / `unit_distance_sub`
  - `unit_velocity_add` / `unit_velocity_sub`
- Added `unit_velocity_from_distance_time` for explicit distance-over-time construction.
- Kept storage/lowering honest: this is a stdlib nominal API over f64 values plus stable unit IDs, not compiler-level `unit<T, dim>` parser/type-checker algebra.

## Skipped surfaces

- No parser/type-checker dimension algebra changes.
- No literal suffix support.
- No UNIT-001..005 semantic diagnostic promotion.
- No 7-vector lowering changes.
- No compiler, bootstrap, `bin/`, R05, ROBO-7, RT, RFC-0063, or Linux package/R06 edits.

## Changed files

- `stdlib/rods/units.nr`
- `tests/features/unit_distance_positive_smoke.nr`
- `tests/features/unit_velocity_positive_smoke.nr`
- `docs/rfcs/v1_PUNCHLIST.md`
- `docs/spec/Nucleor_Error_Codes.md`
- `findings/inbox/helper3_unit1_positive_api_v0842_2026-05-07.md`

## Validation

PASS:

```powershell
.\bin\nucleor.exe build tests\features\unit_distance_positive_smoke.nr -o _unit_distance_positive_v0842 --no-cache
.\target\_unit_distance_positive_v0842.exe
```

Output:

```text
OK unit_distance_positive_smoke
```

PASS:

```powershell
.\bin\nucleor.exe build tests\features\unit_velocity_positive_smoke.nr -o _unit_velocity_positive_v0842 --no-cache
.\target\_unit_velocity_positive_v0842.exe
```

Output:

```text
OK unit_velocity_positive_smoke
```

PASS:

```bash
bash tools/check_rod_void_abi.sh
```

Output:

```text
OK: rod void ABI clean (355 C void nuc_* definitions, 1272 non-void rod externs checked)
```

PASS:

```powershell
git diff --check
```

Output: no findings.

## Gates not run

- `bash tools/check_compiler_drift.sh`: skipped because this queue did not change compiler/tooling metadata.
- `pwsh -NoProfile -File tools\check_perf_regression.ps1`: skipped because this queue did not change compiler or hot toolchain code.
- Self-host / full verify: not required for this isolated stdlib rod + fixture/doc change. Main does not need self-host for this branch; full verify can run at integration time if multiple lanes are batched.

## Main integration note

Cherry-picked onto `integrate/postbatch-v0842` after main had advanced to
`af69b90e`. Integration validation repeated both new fixture builds/runs,
`bash tools/check_rod_void_abi.sh`, and `git diff --check HEAD~1..HEAD`.
All passed. No compiler, bootstrap, or hot toolchain files changed.
