---
title: TYP-011 diagnostic for `str < str` / `str <= str` recommends using `str_cmp(a, b) < 0` as the canonical workaround. `str_cmp` doesn't exist in the stdlib runtime — adopters who follow the recommended workaround get `error[TYP-005]: undefined function 'str_cmp()'` at clang link. Diagnostic-recommended workaround is broken.
severity: silent-miscompute / internal-table-mismatch (sister to vec_contains-symbol-not-emitted)
probe_file: probes/strings/typ011_str_cmp_workaround.nr (probe-branch)
diagnostic_actual: pre-fix — TYP-011 said "Use `str_cmp(a, b) < 0` for canonical lex ordering." Following this advice produced `error[TYP-005]: undefined function 'str_cmp()'`.
diagnostic_expected: either (a) `str_cmp` exists in stdlib (preferred — canonical str API), OR (b) TYP-011's recommendation points at a workaround that DOES exist.
discovered_against: main v0.5.31 (probe rebased)
commit: probe (post-rebase) + main f78d922
status: CLOSED in v0.6.22 via path (b) — diagnostic text now points at a manual element-wise loop using runtime helpers that exist (`str_char_at`, `str_len`, `str_eq`).
---

## Closure (main agent v0.6.22)

`compiler/nucleor_s1_compiler.nr` `type_expr` binop site — updated the
TYP-011 workaround text to point at a manual element-wise loop using
`str_char_at(s, i)` and `str_len(s)`, both of which are real runtime
helpers. The diag also reminds adopters that `str_eq(a, b) == 1` is
the correct equality form.

A real `str_cmp` runtime helper may ship in a future cycle (probably
when the broader str-API expansion lands), at which point this diag
can be reverted to the simpler `str_cmp(a, b) <op> 0` form.

## Repro (now points at a working workaround)

Source:

```nucleor
fn main() -> i32 {
    let a: str = "abc";
    let b: str = "def";
    if a < b { print("less"); } else { print("ge"); };
    0
}
```

v0.6.22 diagnostic:

> error[TYP-011]: `str < str` does pointer comparison (silent
> miscompute — disconnected from lexicographic byte order). Nucleor's
> stdlib does NOT yet expose a `str_cmp` helper; for canonical lex
> ordering, write a manual element-wise loop using `str_char_at(a, i)`
> + `str_char_at(b, i)` over `min(str_len(a), str_len(b))`, then
> break on the first mismatch (or compare lengths if all bytes
> matched). For equality use `str_eq(a, b) == 1`. A real `str_cmp`
> may ship in a future runtime cycle.

## Pure docs change

The diagnostic still fires at the same site under the same conditions
as v0.4.67. Only the workaround text in the diagnostic message is
updated. No code logic change, no AST change, no IR change.

## Promoted

- No fixture (the diagnostic continues to fire on the v0.4.67 fixture
  — only the text changed; no semantic test needed).
- Fix shipped: v0.6.22.
- Promoted: 2026-05-02 PM by main agent (probe commit on
  `origin/probe/exploration`).
