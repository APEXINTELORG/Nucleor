# Feature tests blocked on unimplemented runtime symbols

These 18 positive feature tests come from
`Archive/Nucleor_Copy/examples/` and exercise V1 features whose runtime
support never landed in the OSS distribution. They build to LLVM IR
cleanly but fail at link time with `LNK2019: unresolved external symbol`
on `__nucleor_*` builtins that have no implementation in
`stdlib/runtime/nucleor_llvm_rt.c`.

| Test | Missing symbols |
|---|---|
| `math_int`, `math_extended`, `math_float`, `math_lib`, `math_stdlib` | `__nucleor_abs`, `__nucleor_min`, `__nucleor_max`, … |
| `closure_capture` | `__nucleor_capture_set`, `__nucleor_capture_get` |
| `iter_combinators`, `vec_iter`, `vec_iter_combinators`, `vec_map_filter`, `vec_fold` | `__nucleor_vec_iter`, `__nucleor_vec_take`, `__nucleor_vec_skip`, `__nucleor_vec_sum`, `__nucleor_vec_any`, `__nucleor_vec_fold`, `__nucleor_vec_map`, `__nucleor_vec_filter` |
| `option_result_f64` | `__nucleor_f64_from_scaled`, `__nucleor_i32_to_f64` |
| `overflow_comprehensive`, `overflow_saturating`, `overflow_wrapping` | overflow-mode runtime ops |
| `string_basic`, `string_ops` | `String` heap-string type and its methods (`push`, `len`) — OSS uses `str` + sb_* builders instead |
| `selective_import` | `use "<file>" { name }` selective-import syntax — OSS supports `import "<file>"` only |

Each is a punchlist item: implement the listed builtin in
`nucleor_llvm_rt.c` (and add the IR declaration + builtin mapping in
`compiler/nucleor_s1_compiler.nr`), move the test back up to
`tests/features/`, and the verify gate will start enforcing it.

`tools/verify.ps1` enumerates `tests\features\*.nr` non-recursively, so
nothing in this directory blocks CI.

## trait_bounds.nr

Added 2026-04-29 (v0.4.78). The `<T: Addable>` trait-bound syntax
on generic fns is not yet implemented in the parser — the bound
clause silently parse-recovered pre-fix, producing a binary that
"ran" only because the bound was ignored entirely. Made hidden
when v0.4.78 promoted parse errors to NR020 panics. Move back
once the trait bound parser is wired (audit doc-#1 §8).

## v0.4.100 — 13 fixtures restored to active gate

After v0.4.97-99 closures/Display-Debug/parse_primary work, these
fixtures now build + run without SIGSEGV and have been moved
back to `tests/features/`:

- closure_capture.nr
- math_extended.nr / math_float.nr / math_int.nr / math_lib.nr
  / math_stdlib.nr
- option_result_f64.nr
- selective_import.nr
- string_ops.nr
- vec_fold.nr / vec_iter.nr / vec_iter_combinators.nr
  / vec_map_filter.nr

Still in `_unimplemented/`:
- overflow_comprehensive.nr / overflow_saturating.nr
  (halts with NR021 — needs `sadd.sat`/`ssub.sat`/`smul.sat`
  per-op clamp logic; tracked in audit §3a)
- string_basic.nr (builds but SIGSEGV at runtime — needs
  full `String` heap-string type with `push`/`len`)

## v0.4.101 — `iter_combinators.nr` restored
After adding `__nucleor_vec_chain_i64`, `iter_combinators.nr`
builds + runs and is back in `tests/features/`.

## v0.4.102 — `overflow_wrapping.nr` restored
`wrapping { ... }` is now a parse_primary passthrough block —
default i32/i64 ABI already wraps two's-complement on overflow,
so the block is semantically a no-op today. `saturating { ... }`
still halts cleanly with NR021. Fixture moved back to
`tests/features/`.

## v0.4.103 — `trait_bounds.nr` restored
`<T: Addable>` parse-skips the bound clause in
`parse_generic_params`. Nucleor's monomorphic codegen has always
ignored bounds, so the fixture builds + runs identically to
`<T>(...)`. Fixture moved back to `tests/features/`.
