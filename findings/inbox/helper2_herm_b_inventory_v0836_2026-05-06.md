# Helper2 HERM-B native inventory prototype v0836

Date: 2026-05-06
Owner: helper2
Worktree: `C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828`
Branch: `fix/helper2-herm-b-inventory-v0836`
Base ref: `origin/fix/main-qm7-surface-code-v0827`
Base/merge-base: `e0a5c33e5e917512b4cbd871752fe2471c05f765`

## Result

Added a read-only native Nucleor first slice:

```text
tools/gen_helper_manifest_inventory.nr
```

This is an opt-in HERM-B inventory prototype. It reads the same primary source
surfaces as `tools/gen_helper_manifest.py`, emits stable counts to stdout, and
does not write `docs/rfcs/helper_manifest.toml`.

The canonical drift-gate generator remains:

```text
tools/gen_helper_manifest.py
```

No `tools/check_compiler_drift.sh`, `tools/verify.ps1`, `tools/verify.sh`,
compiler, binary, bootstrap, or manifest-output wiring changed on this branch.

## Native command

```powershell
bin\nucleor.exe build tools\gen_helper_manifest_inventory.nr -o gen_helper_manifest_inventory
target\gen_helper_manifest_inventory.exe
```

Observed output:

```text
helper_manifest_inventory_v1
source: compiler/nucleor_s1_compiler.nr
runtime_dir: stdlib/runtime
runtime_c_files: 189
get_rt_name_pairs: 852
get_rt_name_unique_symbols: 835
is_void_ret_names: 34
is_ptr_ret_names: 131
is_ptr_arg_names: 206
ir_declares_seen: 875
ir_declares_unique_symbols: 875
runtime_direct_symbol_mentions: 1126
runtime_macro_expanded_symbols: 72
runtime_unique_symbols: 821
manifest_candidate_symbols: 875
get_rt_name_symbol_count: 835
get_rt_name_symbol_first: __nucleor_abs,__nucleor_ambient_random,__nucleor_ambient_scheduler,__nucleor_arena_alloc,__nucleor_arena_destroy,__nucleor_arena_new,__nucleor_arena_reset,__nucleor_args_count,__nucleor_args_get,__nucleor_as_f32,__nucleor_as_f64,__nucleor_as_i16
ir_symbol_count: 875
ir_symbol_first: __nucleor_abs,__nucleor_ambient_random,__nucleor_ambient_scheduler,__nucleor_arena_alloc,__nucleor_arena_destroy,__nucleor_arena_new,__nucleor_arena_reset,__nucleor_args_count,__nucleor_args_get,__nucleor_as_f32,__nucleor_as_f64,__nucleor_as_i16
runtime_symbol_count: 821
runtime_symbol_first: __nucleor_abs,__nucleor_arena_alloc,__nucleor_arena_destroy,__nucleor_arena_new,__nucleor_arena_reset,__nucleor_args_count,__nucleor_args_get,__nucleor_as_f32,__nucleor_as_f64,__nucleor_as_i16,__nucleor_as_i32,__nucleor_as_i64
note: read-only inventory only; canonical TOML still comes from tools/gen_helper_manifest.py
```

The important parity signal is:

```text
manifest_candidate_symbols: 875
```

That matches the current Python generator's helper-row total observed in Queue
9 validation.

## What this closes

This branch closes the first safe native HERM-B slice from the v0835 blocker
ledger:

```text
Native inventory prototype that prints counts/keys to stdout and is not wired
into drift.
```

It proves native Nucleor can:

- read `compiler/nucleor_s1_compiler.nr`;
- scan `get_rt_name`-style dispatch rows;
- count `is_void_ret`, `is_ptr_ret`, and `is_ptr_arg` table names;
- scan embedded IR `declare` strings;
- list `stdlib/runtime/*.c`;
- scan `__nucleor_*(` runtime symbol mentions;
- expand the narrow arithmetic overflow macros into the same 9 helper-family
  names per width that the Python generator accounts for;
- produce the 875-symbol candidate manifest surface without Python.

## Still open

HERM-B is not closed. Remaining native-port work:

1. Closed by the v0837 follow-up branch: emit a full sorted
   `candidate_symbol: ...` stream for exact comparison against Python-generated
   TOML symbols, without changing `helper_manifest.toml`.
2. Add native body-slice helpers for `is_void_ret`, `is_ptr_ret`, and future
   return/argument classification if the final TOML needs those fields.
3. Port classification tables only after source inventory parity is locked.
4. Emit TOML only after parser/classifier parity is proven.
5. Switch `tools/check_compiler_drift.sh` from Python to native only after
   zero-diff manifest generation is repeatable.

## Validation

Commands run:

```powershell
bin\nucleor.exe build tools\gen_helper_manifest_inventory.nr -o gen_helper_manifest_inventory
target\gen_helper_manifest_inventory.exe
```

Additional validation required before commit:

```powershell
rg -n "gen_helper_manifest_inventory|helper_manifest_inventory|gen_helper_manifest.py|helper_manifest" tools findings docs compiler
git diff --check
```

Full verify is not required for this opt-in tooling slice.
