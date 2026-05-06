# HERM Native Generator Python Oracles Retired

Date: 2026-05-06
Branch: `fix/main-qm7-surface-code-v0827`

## Summary

Retired the remaining Python generator sources whose native Nucleor generator
paths are already drift-gated:

- `tools/gen_helper_manifest.py`
- `tools/gen_rod_manifest.py`
- `tools/gen_releases_index.py`
- `tools/gen_benchmark_summary.py`

The active generator paths are now:

- `tools/gen_helper_manifest.nr`
- `tools/gen_rod_manifest.nr`
- `tools/gen_releases_index.nr`
- `tools/gen_benchmark_summary.nr`

This does not remove Python interop from the language. It removes old
maintenance helper scripts from the release/toolchain surface so a normal
Nucleor checkout does not carry Python generator assumptions.

## Validation

- `rg --files tools | rg "\.py$"` returns no results.
- `git diff --check` PASS.
- `bash tools/check_compiler_drift.sh` PASS with the existing RFC-0063
  parser-unification warnings only.
