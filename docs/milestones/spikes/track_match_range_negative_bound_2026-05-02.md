# Track Match Negative Range-Bound Diagnostic - 2026-05-02

Branch: `spike/v06-match-range-negative-bound-diagnostic`
Base: `origin/main` `cc8311f` (`v0.6.10`)

## Scope

This closes the E2 doc/diagnostic lane for negative literal bounds in match
range patterns. It does not add negative-bound range-pattern support. It only
replaces the old generic parser failure with a targeted `MATCH-014` diagnostic
that names the limitation and gives the guard workaround.

## Changes

- `parse_match_one_pattern` now detects:
  - negative lower bounds such as `-10..=-1`
  - negative upper bounds such as `0..=-1`
- New diagnostic code `MATCH-014`.
- `nuc explain MATCH-014` title, summary, and fix text.
- Spec and verify code-list wiring.
- Two negative fixtures:
  - `tests/err/err_match_range_negative_lower_bound.nr`
  - `tests/err/err_match_range_negative_upper_bound.nr`

## Validation

- Self-host fixed point: PASS.
  - `target/nuc_match014_stage2.ll`: `8A46EED1C43A50A5AED7C291F72042E2`
  - `target/nuc_match014_stage3.ll`: `8A46EED1C43A50A5AED7C291F72042E2`
- Capped self-host memory:
  - stage2: 588 MB / 770 MB, 4.833s wall
  - stage3: 671 MB / 770 MB, 4.993s wall; crossed the 650 MB warning threshold but stayed below the 770 MB tight cap and 1 GB e-stop
- Capped tools-suite refresh: 424 MB / 580 MB, 4.058s wall.
- Focused verify:
  - `v0.6 MATCH-014 negative range-pattern bounds diagnostic`: PASS, 2.82s step, 56 MB wrapper peak, 65.16s wall
  - `tests/err/*.nr have EXPECT headers`: PASS, 1.07s step
  - `T3.23 diag-code drift (s1 is_known_diag_code vs smoke list)`: PASS, 2.68s step
  - `T3.24 spec-doc drift (canonical codes vs Nucleor_Error_Codes.md)`: PASS
  - `CLI: nuc explain -- full spec code set wired`: PASS, 53 MB wrapper peak, 174.65s wall
- Compiler drift check: PASS.
  - tools-suite ABI tables match s1
  - helper_manifest up to date
  - rod_manifest up to date
  - RELEASES.md up to date
- `git diff --check`: PASS; only PowerShell line-ending warning on `tools/verify.ps1`.
