---
title: `fn f(a: i32, a: i32)` silently shadows the first parameter; no diagnostic, first arg is dropped
severity: missing-error
probe_file: probes/borrows/dup_param_name.nr
diagnostic_actual: none
diagnostic_expected: hard error — duplicate parameter name `a` in fn signature
discovered_against: v0.4.162 (commit 213fee9)
commit: 213fee9e84101dad4a06807f994413d7d4f1cb86
status: CLOSED in v0.4.207 — parse_fn_decl walks each new param against the already-parsed list and panics with NAM-001 on collision. Linear scan in the parser; param lists are small in practice. Regression-guard fixture at tests/fixtures/repro_v207_dup_fn_param_halts.nr.
---

## Repro

```nr
fn add(a: i32, a: i32) -> i32 {
    a + a
}

fn main() -> i32 {
    print_int(add(3, 5));
    0
}
```

## Actual

Compiles clean. Program prints `10` — the second parameter `a` (= 5)
shadows the first `a` (= 3), so `a + a` is `5 + 5`. The first argument
`3` is silently dropped from any use in the body.

## Expected

A hard error at the fn signature:

```
error[NAM-NNN]: identifier `a` is bound more than once in this parameter list.
  --> fn add@line 1:8
  |
1 | fn add(a: i32, a: i32) -> i32 {
  |        ^         ^ second binding of `a`
```

This is a hard error in Rust (`E0415: identifier ... is bound more than
once`) because the only way to reference the shadowed parameter inside
the body is via positional / pattern destructuring, which Nucleor
doesn't have. Silently dropping the first arg means the user's call
site `add(3, 5)` looks like it should yield `8` but produces `10` —
**this is also a silent-miscompute** (the runtime output disagrees with
naive expectation), but the root fix is rejecting at the signature.

## Severity

missing-error (compile-time reject is the canonical fix). Has
silent-miscompute consequences at the call site, but adopters who write
this pattern usually do so by mistake (typo, copy-paste of a parameter
line) rather than intentionally. A hard error catches the typo before
it ships.

## Suspected location

The fn-param parser / sig-typer. Add a duplicate-name check across the
parameter list (a small set, simple linear scan). Same shape of fix as
duplicate field detection in struct decls (which already exists per
`tests/err/err_dup_struct_field.nr`-style fixtures, if any).

## Cross-ref

- `tests/features/borrow_basic.nr` and family — single-named params
  work as expected; this finding is the duplicate-name case.
- The closure_basic.nr fixture's parameter forms also use single-named
  params; this hazard is fn-decl-only.
