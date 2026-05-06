# Helper2 HERM-B native IR ABI parity v0839

Date: 2026-05-06
Owner: helper2
Worktree: `C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828`
Branch: `fix/helper2-herm-b-irabi-v0839`
Base ref: `origin/fix/main-qm7-surface-code-v0827`
Base/merge-base: `f8aa331c08dfc9e7f8f56d389e34f7078862d6c2`

## Result

Extended the opt-in native helper-manifest inventory probe:

```text
tools/gen_helper_manifest_inventory.nr
```

The probe now emits sorted native IR ABI detail records:

```text
ir_abi: __nucleor_symbol|(args) -> ret
```

The ABI records are extracted directly from the compiler source lines that
append LLVM IR `declare` strings. Symbols and ABI strings are sorted together
so the output can be compared directly against the Python-generated TOML
`symbol` and `abi` fields.

The probe output version is now:

```text
helper_manifest_inventory_v3
```

## Validation

Native build and run after rebasing onto
`origin/fix/main-qm7-surface-code-v0827` at
`f8aa331c08dfc9e7f8f56d389e34f7078862d6c2`:

```powershell
bin\nucleor.exe build tools\gen_helper_manifest_inventory.nr -o gen_helper_manifest_inventory
target\gen_helper_manifest_inventory.exe |
  Set-Content -LiteralPath target\helper_manifest_inventory_v0839.txt -Encoding ascii
```

Observed native counts:

```text
ir_abi_lines=875
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

Native ABI comparison against generated TOML `abi` fields:

```text
native_abi_count=875
toml_abi_count=875
abi_diff_count=0
```

Candidate-symbol comparison against generated TOML symbols:

```text
native_candidate_count=875
toml_symbol_count=875
candidate_diff_count=0
```

`python tools\gen_helper_manifest.py` rewrote
`docs/rfcs/helper_manifest.toml`; the file was restored before commit because
this branch does not change generated TOML.

Also checked:

```powershell
git diff --check
```

## Rebase note

Before this slice, `origin/fix/main-qm7-surface-code-v0827` advanced from
`4fa77dbd24a18e4e914afdabf5d7031fcb18187e` to
`f8aa331c08dfc9e7f8f56d389e34f7078862d6c2`. The active helper stack was
rebased onto the newer integration base, and the prior HERM-B report metadata
in this branch was updated to name the current merge-base.

## Non-goals

This branch does not:

- replace `tools/gen_helper_manifest.py`;
- write or commit `docs/rfcs/helper_manifest.toml`;
- change `tools/check_compiler_drift.sh`;
- change `tools/verify.ps1` or `tools/verify.sh`;
- edit compiler, binary, bootstrap, runtime, or manifest files.

## Remaining HERM-B work

Still open after v0839:

1. Port classification tables after inventory, table-list, and ABI-field
   parity are locked.
2. Emit TOML only after parser/classifier parity is proven.
3. Switch the drift gate from Python to native only after zero-diff manifest
   generation is repeatable.

Full verify is not required for this opt-in tooling slice.
