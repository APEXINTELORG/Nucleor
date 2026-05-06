# Helper2 HERM-B native policy-field parity v0842

Date: 2026-05-06
Owner: helper2
Worktree: `C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828`
Branch: `fix/helper2-herm-b-policy-v0842`
Base ref: `origin/fix/main-qm7-surface-code-v0827`
Base/merge-base: `e6282cca3a3f2d7e08828f53e56fb094803b81fc`

## Result

Extended the opt-in native helper-manifest inventory probe:

```text
tools/gen_helper_manifest_inventory.nr
```

The probe now emits sorted native policy rows:

```text
policy_row: __nucleor_symbol|effects|taint|units|proof_obligation
```

The native resolver mirrors the Python generator resolution order for these
fields:

```text
NAME_OVERRIDES -> PATTERN_OVERRIDES -> CLASS_DEFAULTS -> TODO
```

The probe output version is now:

```text
helper_manifest_inventory_v6
```

## Validation

Native build and run:

```powershell
bin\nucleor.exe build tools\gen_helper_manifest_inventory.nr -o gen_helper_manifest_inventory
target\gen_helper_manifest_inventory.exe |
  Set-Content -LiteralPath target\helper_manifest_inventory_v0842.txt -Encoding ascii
```

Observed native counts:

```text
manifest_named_symbols=875
policy_rows=875
policy_todo_symbols=59
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

Native policy comparison against generated TOML rows:

```text
native_policy_count=875
toml_policy_count=875
policy_diff_count=0
native_policy_todo_count=59
toml_policy_todo_count=59
```

`python tools\gen_helper_manifest.py` rewrote
`docs/rfcs/helper_manifest.toml`; the file was restored before commit because
this branch does not change generated TOML.

Also checked:

```powershell
git diff --check
```

## Base note

The previous v0841 helper branch was based on
`f8aa331c08dfc9e7f8f56d389e34f7078862d6c2`. Before v0842,
`origin/fix/main-qm7-surface-code-v0827` advanced to
`e6282cca3a3f2d7e08828f53e56fb094803b81fc`, and the prior HERM-B commits were
already present in the integration base by patch-id. This branch starts from
that current base and only adds v0842 policy-field output.

## Non-goals

This branch does not:

- replace `tools/gen_helper_manifest.py`;
- write or commit `docs/rfcs/helper_manifest.toml`;
- change `tools/check_compiler_drift.sh`;
- change `tools/verify.ps1` or `tools/verify.sh`;
- edit compiler, binary, bootstrap, runtime, or manifest files.

## Remaining HERM-B work

Still open after v0842:

1. Port `since` map parity.
2. Port `notes` text parity.
3. Emit TOML only after all row-field parity is proven.
4. Switch the drift gate from Python to native only after zero-diff manifest
   generation is repeatable.

Full verify is not required for this opt-in tooling slice.
