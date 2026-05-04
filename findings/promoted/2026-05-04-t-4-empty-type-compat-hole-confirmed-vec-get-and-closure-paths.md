---
title: T-4 — empty-type compatibility hole confirmed; `vec_get` and un-annotated closure paths silently accept wrong-typed flow
severity: silent-miscompute
probe_file: probes/types/t_4_empty_type_compat_hole.nr (vec_get path) + probes/types/t_4_empty_via_closure_noannot.nr (closure path)
diagnostic_actual: build success, rc=0, mistyped value stored in mistyped binding silently
diagnostic_expected: TYP-008 type mismatch
discovered_against: v0.4.180
commit: 53af3b53
status: NEW
---

## Repro 1 — `vec_get` element-type erasure feeds the empty-type hole

```nr
fn main() -> i32 {
    let xs: Vec<i64> = vec![1, 2, 3];
    let first: bool = xs[0];      // xs[0] is i64; declared bool — should TYP-008
    print_int(first as i64);
    return 0;
}
```

```
$ bin/nucleor.exe build probes/types/t_4_empty_type_compat_hole.nr
  ... (clean build, no diagnostic)
  compiled: target\t_4_empty_type_compat_hole.exe
$ ./target/t_4_empty_type_compat_hole.exe
1
rc=0
```

Cross-references RFC T-10 (Vec<T> element-type propagation through `vec_get` unshipped). When the type-checker computes `xs[0]`'s type it returns `""` (or some legacy-cell sentinel that resolves to `""`), and `types_compatible("bool", "")` short-circuits to 1 in `nucleor_s1_compiler.nr:16134`:

```nr
fn types_compatible(expected: str, actual: str) -> i64 {
    if str_len(expected) == 0 || str_len(actual) == 0 { return 1; };
    ...
}
```

## Repro 2 — un-annotated closure param feeds the empty-type hole

```nr
fn main() -> i32 {
    let g = |x| x;            // identity, no annotation
    let r: bool = g(99);      // 99 is i64; r declared bool — should TYP-008
    print_int(r as i64);
    return 0;
}
```

```
$ bin/nucleor.exe build probes/types/t_4_empty_via_closure_noannot.nr
  compiled: target\t_4_empty_via_closure_noannot.exe
$ ./target/t_4_empty_via_closure_noannot.exe
99
rc=0
```

Closure `g` has no parameter annotation. The type-checker has no inferred return type for `g`, so the call site `g(99)` resolves to `""`, and `types_compatible("bool", "")` short-circuits to 1.

## Sister shapes that DO catch the mistyped flow (negative controls)

For comparison, these shapes did emit TYP-008 against the same compiler:

```nr
let bad: str = (|x: i64| x * 2)(5);    // closure with annotated param
let nested: str = ret_i64();           // direct call to fn with -> i64 sig
```

Both produced clean `TYP-008` errors. The hole only opens when the callee's type information is absent or an inference returns "".

## Suspected location

`compiler/nucleor_s1_compiler.nr:16133-16135`:

```nr
fn types_compatible(expected: str, actual: str) -> i64 {
    if str_len(expected) == 0 || str_len(actual) == 0 { return 1; };
    if str_eq(expected, "_") == 1 { return 1; };
    if str_eq(actual, "_") == 1 { return 1; };
```

The early-return for empty string was almost certainly added as a "don't break inference cascade" pragmatic fix at some point, but it converts inference failure into silent accept. RFC T-4 calls for removal of this branch entirely — when type information is absent, the correct response is `TYP-027` (type inference failed; explicit annotation required), not silent compatibility.

## Severity

**silent-miscompute** — exactly as RFC describes. Any code path that goes through a closure with un-annotated parameters or a `Vec<T>::get` flows wrong types into wrong bindings without diagnostic. Worst-case adopter pattern: typing an `if` condition as `bool` from a function/closure return whose inferred type went to "". The branch silently uses raw i64 truthiness — works for 0/1 but produces confusing control flow when the value is non-{0,1}.

## Suggested fix

**Phase 1 (immediate, single-line):**

```nr
// Before:
if str_len(expected) == 0 || str_len(actual) == 0 { return 1; };
// After:
if str_len(expected) == 0 || str_len(actual) == 0 { return 0; };
```

This converts every existing "" inference fallthrough into a hard reject. It will surface a wave of NOW-firing TYP-008/TYP-027 errors, which need to be triaged. Probably a feature-flagged rollout: `NUC_STRICT_INFERENCE=1` enables the strict path, default off, then flip after the wave is drained.

**Phase 2:** Improve `infer_var_type_from_source` so the failure rate drops dramatically. RFC T-4 §3.3 Phase 2 covers this (cross-references T-9). The two main shapes to close:

- Closure return-type inference (when the body has a single `return expr` or expression body, propagate `expr`'s type as the closure's return type)
- `vec_get` / `[i]` element-type propagation (close RFC T-10 — element-type tracking through `Vec<T>` access)

After Phase 2 the strict-mode rejection rate drops to "actual missing annotations", which the user explicitly fixes with explicit `let` types. Phase 4 (`v1.0` cut) flips the strict-mode default.

## Cross-ref

- `compiler/nucleor_s1_compiler.nr:16133` — types_compatible early return on empty
- `compiler/nucleor_s1_compiler.nr:29049` — infer_var_type_from_source (the regex source-scanner whose failures feed the hole)
- T-3 sister finding (char-int wildcard) — same `types_compatible` lives in the same function
- T-9 (inference is source-text scanning) — root cause of empty-string returns
- T-10 (Vec<T> element propagation unshipped) — direct path to the hole via `xs[0]`
- RFC: §T-4 in the type-system gap analysis

## Notes

The two-line fix (`return 0` instead of `return 1`) is small but high-blast-radius. Recommend gating it behind a NUC_STRICT_INFERENCE env flag for a release cycle so adopters and the compiler itself can fix any latent annotation gaps surfaced by the strict mode. The compiler self-host source likely depends on the existing lenient behavior in places — running the strict-mode build will identify them mechanically.
