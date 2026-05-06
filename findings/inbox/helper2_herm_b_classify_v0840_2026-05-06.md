# Helper2 HERM-B native classification parity v0840

Date: 2026-05-06
Owner: helper2
Worktree: `C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828`
Branch: `fix/helper2-herm-b-classify-v0840`
Base ref: `origin/fix/main-qm7-surface-code-v0827`
Base/merge-base: `f8aa331c08dfc9e7f8f56d389e34f7078862d6c2`
Parent helper branch: `fix/helper2-herm-b-irabi-v0839`

## Result

Extended the opt-in native helper-manifest inventory probe:

```text
tools/gen_helper_manifest_inventory.nr
```

The probe now emits sorted native class rows:

```text
class_row: __nucleor_symbol|helper_name|ClassName
```

The native classifier ports the Python generator's class-rule order into
standalone Nucleor code. It classifies the same manifest candidate set built
from `get_rt_name` first-name mappings plus IR-only helper symbols.

The probe output version is now:

```text
helper_manifest_inventory_v4
```

## Validation

Native build and run:

```powershell
bin\nucleor.exe build tools\gen_helper_manifest_inventory.nr -o gen_helper_manifest_inventory
target\gen_helper_manifest_inventory.exe |
  Set-Content -LiteralPath target\helper_manifest_inventory_v0840.txt -Encoding ascii
```

Observed native counts:

```text
class_row_lines=875
manifest_named_symbols=875
candidate_symbol_lines=875
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

Native `symbol|class` comparison against generated TOML rows:

```text
native_class_count=875
toml_class_count=875
class_diff_count=0
```

Native class summary:

```text
ADT=22
Allocation=14
Collection=56
Concurrency=40
ControlFlow=6
DataCodec=19
Introspection=19
IO=73
PanickingArith=101
PureMath=181
Random=13
StringFormat=131
TensorOps=45
Time=21
ToolingMeta=21
VectorOps=113
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

Still open after v0840:

1. Port policy fields: effects, taint, units, proof obligation, stability,
   since, and notes.
2. Emit TOML only after row-field parity is proven.
3. Switch the drift gate from Python to native only after zero-diff manifest
   generation is repeatable.

Full verify is not required for this opt-in tooling slice.
