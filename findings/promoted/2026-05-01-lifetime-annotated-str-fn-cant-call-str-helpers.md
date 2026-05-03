---
title: `fn f<'a>(x: &'a str) -> &'a str` body cannot call `str_len(x)` / `print(x)` / etc. — `&'a str` is treated as `&str` and str-helpers reject the borrow with TYP-006 "must be str (runtime helper)"
severity: silent-miscompute / wrong-error (lifetime-annotated str fn body unusable with str runtime helpers)
probe_file: probes/lifetimes/lifetime_str_fn.nr (probe-branch)
diagnostic_actual: pre-fix — TYP-006 on every str-helper call site inside a lifetime-annotated fn body taking `&'a str` parameters.
diagnostic_expected: helper accepts the borrow form (Rust convention) since `&str` lowers identically to `str` in the IR.
discovered_against: main v0.5.18 (probe rebased)
commit: probe (post-rebase) + main 1b70cec
status: CLOSED in v0.6.48 — sister-fix of `2026-05-02-str-runtime-helpers-reject-amp-but-strict-accepts`. The TYP-006 widen to accept `&str` also covers `&'a str` because the type system erases lifetimes to the bare `&str` shape before the arg-type check runs.
---

## Closure (incidental — v0.6.48 sister-fix)

The same v0.6.48 widen of TYP-006 arg-0 / arg-1 to accept `&str`
(in addition to `str` and `_`) fixes this finding too. Inside a
lifetime-annotated fn body, parameters typed `&'a str` carry the
type `&str` after lifetime erasure (the parser consumes the
lifetime token but doesn't propagate it into the type-string used
by `type_expr`). So at the helper call site, `arg0_t == "&str"`,
which v0.6.48 now allows.

## Adopter migration

```nucleor
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {
    if str_len(x) > str_len(y) { x } else { y }
}

fn main() -> i32 {
    let s: str = "hello";
    let t: str = "world!";
    print(longest(s, t));   // prints "world!"
    return 0;
}
```

Pre-v0.6.48 this emitted `error[TYP-006]: argument 0 of 'str_len'
must be str (runtime helper)` for every helper call inside the
lifetime-annotated body. Post-v0.6.48 it compiles and runs
correctly.

## Validation

```
target/_lt_repro.nr   --> compiles + prints "world!"
```

## Forward-roadmap

Lifetime ELISION + lifetime CHECKING are still gaps in Nucleor v0.6
(parser accepts the syntax for translation-fidelity but the
borrow-checker doesn't enforce lifetime invariants). That's a
separate, larger workstream. v0.6.48 only paves over the
ergonomic blocker for adopters porting Rust code that uses
lifetime-annotated str fns.

## Promoted

- Validation: `target/_lt_repro.nr` smoke (longest fn) compiles +
  runs.
- Fix shipped: v0.6.48 (sister to the str helper amp finding).
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
