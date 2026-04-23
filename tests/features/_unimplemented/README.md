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
