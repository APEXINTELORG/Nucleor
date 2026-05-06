# Helper2 HERM-B native key-list parity v0837

Date: 2026-05-06
Owner: helper2
Worktree: `C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828`
Branch: `fix/helper2-herm-b-keylist-v0837`
Base ref: `origin/fix/main-qm7-surface-code-v0827`
Base/merge-base: `f8aa331c08dfc9e7f8f56d389e34f7078862d6c2`

## Result

Extended the opt-in native HERM-B inventory probe:

```text
tools/gen_helper_manifest_inventory.nr
```

The probe now emits one sorted line per candidate manifest symbol:

```text
candidate_symbol: __nucleor_abs
candidate_symbol: __nucleor_ambient_random
...
```

This closes the next safe HERM-B slice after v0836: exact key-list comparison
against the Python-generated TOML symbol rows, without changing
`docs/rfcs/helper_manifest.toml` and without wiring the native probe into the
drift gate.

## Validation

Native build:

```powershell
bin\nucleor.exe build tools\gen_helper_manifest_inventory.nr -o gen_helper_manifest_inventory
```

Native run:

```powershell
target\gen_helper_manifest_inventory.exe |
  Set-Content -LiteralPath target\helper_manifest_inventory_v0837.txt -Encoding ascii
```

Observed key counts:

```text
manifest_candidate_symbols: 875
candidate_symbol lines: 875
```

Python oracle:

```powershell
python tools\gen_helper_manifest.py
```

Observed Python generator output:

```text
Total helpers: 875
REVIEW REQUIRED: 0
```

Exact symbol comparison command:

```powershell
$native = Select-String -LiteralPath target\helper_manifest_inventory_v0837.txt -Pattern '^candidate_symbol: ' |
  ForEach-Object { $_.Line.Substring('candidate_symbol: '.Length) } |
  Sort-Object -Unique
$toml = Select-String -LiteralPath docs\rfcs\helper_manifest.toml -Pattern '^symbol\s*=\s*"([^"]+)"' |
  ForEach-Object { $_.Matches[0].Groups[1].Value } |
  Sort-Object -Unique
$diff = Compare-Object -ReferenceObject $toml -DifferenceObject $native
```

Observed comparison result:

```text
native_count=875
toml_count=875
diff_count=0
```

`python tools\gen_helper_manifest.py` rewrote
`docs/rfcs/helper_manifest.toml` with no content diff other than line-ending
normalization warning; the file was restored before commit.

## Non-goals

This branch does not:

- replace `tools/gen_helper_manifest.py`;
- write `docs/rfcs/helper_manifest.toml`;
- change `tools/check_compiler_drift.sh`;
- change `tools/verify.ps1` or `tools/verify.sh`;
- edit compiler, binary, bootstrap, or runtime files.

## Remaining HERM-B work

Still open after v0837:

1. Add native body-slice helpers for return/argument classification surfaces
   once exact symbol inventory remains stable across integration-base drift.
2. Port classification tables only after inventory and body-slice parity are
   locked.
3. Emit TOML only after parser/classifier parity is proven.
4. Switch the drift gate from Python to native only after zero-diff manifest
   generation is repeatable.

Full verify is not required for this opt-in tooling slice.
