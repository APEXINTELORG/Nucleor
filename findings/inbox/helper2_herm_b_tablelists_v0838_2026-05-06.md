# Helper2 HERM-B native table-list parity v0838

Date: 2026-05-06
Owner: helper2
Worktree: `C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828`
Branch: `fix/helper2-herm-b-tablelists-v0838`
Base ref: `origin/fix/main-qm7-surface-code-v0827`
Base/merge-base: `f8aa331c08dfc9e7f8f56d389e34f7078862d6c2`

## Result

Extended the opt-in native helper-manifest inventory probe:

```text
tools/gen_helper_manifest_inventory.nr
```

The probe now emits full sorted key lists for the compiler ABI body tables:

```text
void_ret_name: ...
ptr_ret_name: ...
ptr_arg_name: ...
```

It also fixes the table scanner. The earlier prototype used a loose "next
function" boundary and a loose "later return 1" test. That was enough for the
symbol candidate inventory, but it was not safe for return/argument table
parity because attributed functions and explicit `return 0` rows could be
misread. v0838 replaces that with:

- brace-aware function-body matching;
- per-source-line `return 1;` checks for each `if str_eq(name, "...")` row.

The probe output version is now:

```text
helper_manifest_inventory_v2
```

## Validation

Native build and run:

```powershell
bin\nucleor.exe build tools\gen_helper_manifest_inventory.nr -o gen_helper_manifest_inventory
target\gen_helper_manifest_inventory.exe |
  Set-Content -LiteralPath target\helper_manifest_inventory_v0838.txt -Encoding ascii
```

Observed native counts:

```text
void_ret_lines=33
ptr_ret_lines=126
ptr_arg_lines=204
candidate_symbol_lines=875
```

Source-oracle comparison:

```text
label=void_ret_name
native_count=33
source_count=33
diff_count=0

label=ptr_ret_name
native_count=126
source_count=126
diff_count=0

label=ptr_arg_name
native_count=204
source_count=204
diff_count=0
```

Python/TOML symbol oracle:

```powershell
python tools\gen_helper_manifest.py
```

Observed Python generator output:

```text
Total helpers: 875
REVIEW REQUIRED: 0
```

Candidate-symbol comparison against generated TOML symbols:

```text
native_symbol_count=875
toml_symbol_count=875
symbol_diff_count=0
```

`python tools\gen_helper_manifest.py` rewrote
`docs/rfcs/helper_manifest.toml`; the file was restored before commit because
this branch does not change generated TOML.

## Non-goals

This branch does not:

- replace `tools/gen_helper_manifest.py`;
- write or commit `docs/rfcs/helper_manifest.toml`;
- change `tools/check_compiler_drift.sh`;
- change `tools/verify.ps1` or `tools/verify.sh`;
- edit compiler, binary, bootstrap, runtime, or manifest files.

## Remaining HERM-B work

Still open after v0838:

1. Add native IR ABI detail extraction for return type and argument type lists,
   then compare against generated TOML `abi` fields.
2. Port classification tables only after inventory and ABI-field parity are
   locked.
3. Emit TOML only after parser/classifier parity is proven.
4. Switch the drift gate from Python to native only after zero-diff manifest
   generation is repeatable.

Full verify is not required for this opt-in tooling slice.
