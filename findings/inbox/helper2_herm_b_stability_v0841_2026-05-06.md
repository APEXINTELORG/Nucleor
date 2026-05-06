# Helper2 HERM-B native stability parity v0841

Date: 2026-05-06
Owner: helper2
Worktree: `C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828`
Branch: `fix/helper2-herm-b-stability-v0841`
Base ref: `origin/fix/main-qm7-surface-code-v0827`
Base/merge-base: `f8aa331c08dfc9e7f8f56d389e34f7078862d6c2`
Parent helper branch: `fix/helper2-herm-b-classify-v0840`

## Result

Extended the opt-in native helper-manifest inventory probe:

```text
tools/gen_helper_manifest_inventory.nr
```

The probe now emits sorted native stability rows:

```text
stability_row: __nucleor_symbol|stable
stability_row: __nucleor_symbol|unstable
stability_row: __nucleor_symbol|experimental
```

The native stability logic mirrors the Python generator's rule:

- `stable` when the symbol is defined in `stdlib/runtime/*.c`, including
  expanded narrow-width overflow macros;
- `unstable` when the symbol is intentionally declared as a forward-compatible
  placeholder;
- `experimental` otherwise, which would trigger review.

The probe output version is now:

```text
helper_manifest_inventory_v5
```

## Validation

Native build and run:

```powershell
bin\nucleor.exe build tools\gen_helper_manifest_inventory.nr -o gen_helper_manifest_inventory
target\gen_helper_manifest_inventory.exe |
  Set-Content -LiteralPath target\helper_manifest_inventory_v0841.txt -Encoding ascii
```

Observed native counts:

```text
stability_rows=875
stable_symbols=804
unstable_symbols=71
experimental_symbols=0
review_required_symbols=0
```

Python/TOML oracle:

```powershell
python tools\gen_helper_manifest.py
```

Observed Python generator output:

```text
Total helpers: 875
REVIEW REQUIRED: 0
```

Native `symbol|stability` comparison against generated TOML rows:

```text
native_stability_count=875
toml_stability_count=875
stability_diff_count=0
```

Native stability summary:

```text
stable=804
unstable=71
```

`python tools\gen_helper_manifest.py` rewrote
`docs/rfcs/helper_manifest.toml`; the file was restored before commit because
this branch does not change generated TOML.

Also checked:

```powershell
git diff --check
```

## Non-goals

This branch does not:

- replace `tools/gen_helper_manifest.py`;
- write or commit `docs/rfcs/helper_manifest.toml`;
- change `tools/check_compiler_drift.sh`;
- change `tools/verify.ps1` or `tools/verify.sh`;
- edit compiler, binary, bootstrap, runtime, or manifest files.

## Remaining HERM-B work

Still open after v0841:

1. Port policy fields: effects, taint, units, proof obligation, since, and
   notes text.
2. Emit TOML only after row-field parity is proven.
3. Switch the drift gate from Python to native only after zero-diff manifest
   generation is repeatable.

Full verify is not required for this opt-in tooling slice.
