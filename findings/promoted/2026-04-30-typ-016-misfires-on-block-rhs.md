---
title: TYP-016 ("if expression missing else branch") misfires on plain block-expression let-RHS
severity: wrong-error
probe_file: probes/arith/let_block_rhs_simple.nr
diagnostic_actual: 'error[TYP-016]: `if` expression assigned to binding `r` of type `i32` is missing an `else` branch.'
diagnostic_expected: clean compile (block-as-RHS is canonical Rust idiom)
discovered_against: v0.4.162 (commit 213fee9)
commit: 213fee9e84101dad4a06807f994413d7d4f1cb86
status: ALREADY CLOSED (verified at v0.4.205) — the v0.4.164 TYP-016-misfire-on-synthesized-passthrough-block fix at compiler/nucleor_s1_compiler.nr:12722-12740 narrowed the check to actual `if`-expression nodes only. The probe `let r: i32 = { 42 };` now compiles cleanly and prints 42. Filing this for archival completeness; no additional ship needed.
---

## Repro

```nr
fn main() -> i32 {
    let r: i32 = { 42 };
    print_int(r);
    0
}
```

## Actual

```
$ ./bin/nucleor.exe build probes/arith/let_block_rhs_simple.nr -o p
error[TYP-016]: `if` expression assigned to binding `r` of type `i32` is missing an `else` branch. Pre-v0.4.126 the false-condition path silently fell through to the alloca's zero-init slot — `let x: i64 = if false { 5 };` produced `x == 0` with no signal. Add an `else { ... }` arm that produces the same type, or restructure to a stmt-form `if` that doesn't assign.
  --> fn main@line 2:9
  |
2 |     let r: i32 = {
  |         ^
```

There is **no `if`-expression** in the source. The RHS is a plain
block-expression `{ 42 }`. TYP-016 should fire only when the RHS is an
`if` without an `else` (the v0.4.126 silent-init-from-zero hazard);
firing it on a plain block misclassifies the construct.

## Expected

Clean compile; `r` is bound to the block's tail expression value `42`,
program prints `42`. This is canonical Rust idiom (and the probe shows
the existing code already supports block-tail return — see
`tests/features/_unimplemented/...` if any, or `closure_basic.nr` fixture
which uses bare-expr but the lowering is the same kind).

## Severity

wrong-error. The diagnostic mislabels the construct; users seeing
"`if` expression assigned to binding" while their source has no `if` are
misled. Workarounds force unidiomatic code (`let r = 42;` strips the
block; `let r = if true { 42 } else { 42 };` adds dead branches).

## Suspected location

The TYP-016 emit site in the let-RHS type-check / lowering. v0.4.126
added the `if` without `else` reject. The check is probably scoped too
broadly — it fires on ANY block-shaped RHS rather than specifically on
an `if`-expression node missing an `else` branch. Narrow the check to
`kind == <if-expr>` AST nodes only.

This finding likely also triggers the four pre-existing FAILs in the
verify suite (`features/overflow_comprehensive`,
`features/overflow_wrapping`, `lang/closures`, `runtime/concurrency`)
that all reference TYP-016 in their error output. If so, fixing this
finding closes those baseline FAILs at the same time — a 4× promotion
on the verify count.

## Cross-ref

- v0.4.126 (TYP-016 close — `if` without `else` silent-init-from-zero):
  the original ship, which over-fired into block-RHS territory.
- Pre-existing baseline verify FAILs that reference TYP-016:
  `tests/features/overflow_comprehensive.nr`,
  `tests/features/overflow_wrapping.nr` (likely cause of the 6-FAIL
  baseline noted in the heartbeat).


## Promoted

- Status frontmatter: see top of file. Closure version: **v0.4.205**.
- Verify gate: existing per-feature loop picks up the fixture above.
- Promoted: 2026-04-30 by main agent (footer backfilled 2026-05-01 per probe-agent Q3 footer-shape uniformity request).
