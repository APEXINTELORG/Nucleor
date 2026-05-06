# Helper2 HERM-B native notes parity v0844

Date: 2026-05-06
Owner: helper2
Worktree: `C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828`
Branch: `fix/helper2-herm-b-notes-v0844`
Base ref: `origin/fix/main-qm7-surface-code-v0827`
Base/merge-base: `e6282cca3a3f2d7e08828f53e56fb094803b81fc`
Parent helper branch: `fix/helper2-herm-b-since-v0843`

## Result

Extended the opt-in native helper-manifest inventory probe:

```text
tools/gen_helper_manifest_inventory.nr
```

The probe now emits sorted native notes rows:

```text
notes_row: __nucleor_symbol|notes text
```

The native notes resolver mirrors the Python generator behavior for:

- intentional placeholder notes;
- experimental undefined-symbol review notes;
- unclassified-name review notes;
- semicolon joining when more than one note applies.

The probe output version is now:

```text
helper_manifest_inventory_v8
```

## Validation

Native build and run:

```powershell
bin\nucleor.exe build tools\gen_helper_manifest_inventory.nr -o gen_helper_manifest_inventory
target\gen_helper_manifest_inventory.exe |
  Set-Content -LiteralPath target\helper_manifest_inventory_v0844.txt -Encoding ascii
```

Observed native counts:

```text
manifest_named_symbols=875
notes_rows=875
notes_nonempty_symbols=71
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

Native notes comparison against generated TOML rows:

```text
native_notes_count=875
toml_notes_count=875
notes_diff_count=0
native_notes_nonempty_count=71
toml_notes_nonempty_count=71
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

Still open after v0844:

1. Emit TOML from the native probe after all row-field parity is proven.
2. Compare native TOML against Python-generated TOML byte-for-byte or with a
   documented newline-normalized zero-diff check.
3. Switch the drift gate from Python to native only after zero-diff manifest
   generation is repeatable.

Full verify is not required for this opt-in tooling slice.
