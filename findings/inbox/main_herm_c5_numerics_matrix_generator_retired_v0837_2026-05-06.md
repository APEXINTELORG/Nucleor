# HERM-C5 Numerics Matrix Generator Retirement

Date: 2026-05-06
Branch: `fix/main-qm7-surface-code-v0827`

## Summary

Retired `tools/gen_numerics_matrix.py` instead of porting it. The script was
optional/offline, not used by product, verify, bootstrap, release, or drift
paths, and the roadmap already recorded that it rewrote committed numerics
matrix fixtures back to older syntax.

The numerics matrix remains in `tests/lang/numerics_matrix/` as curated
committed fixtures. Operators should add or update cases directly in that tree
and run the existing dedicated runners:

```powershell
pwsh tools/run_numerics_matrix.ps1
```

```bash
bash tools/run_numerics_matrix.sh
```

## Files

- Deleted: `tools/gen_numerics_matrix.py`
- Updated: `tests/lang/numerics_matrix/MANIFEST.md`
- Updated: `tools/gen_helper_manifest.nr`
- Updated: `docs/rfcs/RFC-0063-production-readiness-roadmap.md`
- Updated: `docs/rfcs/v1_REMAINING_PUNCHLIST_CLOUD_DISPATCH_v0834_2026-05-06.md`

## Validation

- `rg -n "gen_numerics_matrix.py|gen_numerics_matrix" tools docs tests`
  returns only retired-status documentation references; no active tool path
  remains.
- `git diff --check` PASS.
- `bash tools/check_compiler_drift.sh` PASS with the existing RFC-0063
  parser-unification warnings only.
