---
title: `?` operator on `Option<T>::Some` panics with `vec_get OOB` then continues running
severity: crash
probe_file: probes/options/question_propagate.nr
diagnostic_actual: "PANIC: vec_get OOB: index 1, len 1" at runtime, then program continues and prints garbage value, exits non-zero
diagnostic_expected: clean unwrap — `Some(5)?` yields `5`; the inner expression continues with the unwrapped value
discovered_against: v0.4.162 (commit 213fee9)
commit: 213fee9e84101dad4a06807f994413d7d4f1cb86
---

## Repro

```nr
fn safe_div(a: i32, b: i32) -> Option<i32> {
    if b == 0 { None } else { Some(a / b) }
}

fn double_safe(a: i32, b: i32) -> Option<i32> {
    let v: i32 = safe_div(a, b)?;
    Some(v * 2)
}

fn main() -> i32 {
    let r: Option<i32> = double_safe(20, 4);
    match r {
        Some(v) => print_int(v),
        None => print_int(-1),
    };
    let r2: Option<i32> = double_safe(20, 0);
    match r2 {
        Some(v) => print_int(v),
        None => print_int(-1),
    };
    0
}
```

## Actual

```
$ ./target/question_propagate.exe
PANIC: vec_get OOB: index 1, len 1 (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)
5
[exit 1]
```

The panic message indicates the `?` operator (or its lowering through
the kind-49 / kind-50 dispatch on `Option<T>`) is reading
`vec_get(some_vec, 1)` against a Vec of length 1. The Some-variant
internal representation of `Option<i32>` should carry the wrapped value
in the underlying Vec, but either the layout is `[discriminant]` only
(value lost at construction) or the index-1 read is wrong for this
variant.

Despite the PANIC, the program does not abort — it continues, prints `5`
(unclear provenance — likely the partial unwrap leaking the divisor or
similar), then exits 1.

For comparison, **direct match on `Option<i32>` works correctly**:
`probes/options/option_some_unwrap.nr` matches `Some(v)` and prints
`5` and `-1` cleanly with no PANIC. So Option construction + match work;
only the `?` lowering is broken.

## Expected

`Some(5)?` yields `5`. `double_safe(20, 4)` returns `Some(10)`,
`double_safe(20, 0)` returns `None`. `main` prints `10` then `-1`.

## Severity

crash. Runtime PANIC with no compile-time signal. SIGSEGV-class — the
v0.4.143 NUM-023 ship explicitly listed runtime SIGSEGVs as URGENT and
shipped a same-day fix. v0.4.157 closed `?` on non-Result var; this is
the sibling case where `?` on a *valid* `Option<T>` Some-variant still
crashes.

## Suspected location

The `?`-operator lowering on `Option<T>` receivers. Grep likely targets:
- `kind-50` (or whichever AST kind is the `?` operator)
- `__nucleor_option_unwrap` / `option_get_value` runtime helpers
- the lowering site that reads the inner value out of an `Option<T>`

The OOB at `index 1, len 1` strongly suggests the lowering assumes a
`[discriminant, value]` 2-element Vec layout but the actual construction
is producing a `[discriminant]` 1-element Vec, OR the lowering's index
arithmetic is off-by-one.

Cross-check with how the working match path reads the Some payload —
that codegen path is correct; the `?` path likely diverges from it.

## Cross-ref

- v0.4.157 (TYP-011 ext: `?` on non-Result var). Same `?` lowering
  family.
- v0.4.143 (NUM-023): runtime SIGSEGV close — same severity tier.
- `tests/features/closure_basic.nr` shows the working Option match
  pattern.
