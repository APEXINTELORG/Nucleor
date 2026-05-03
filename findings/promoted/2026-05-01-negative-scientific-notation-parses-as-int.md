---
title: `-1e10` and `-1e20` (negative scientific-notation float literals) parse as integer-typed expressions, not f64. `let b: f64 = -1e10;` fires NUM-020 "integer-typed expression cannot initialize float binding".
severity: silent-miscompute / wrong-error (lexer/parser gap on negative scientific notation)
probe_file: probes/numeric/neg_scientific_notation.nr (probe-branch)
diagnostic_actual: pre-fix — `error[NUM-020]: integer-typed expression (i32) cannot initialize float binding b of type f64`.
diagnostic_expected: build succeeds — `-1e10` is a valid f64 literal (= -10,000,000,000.0).
discovered_against: main v0.5.18 (probe ebbcc16)
commit: probe ebbcc16 + verified clean against main 6b8bcb50
status: ALREADY CLOSED — verified clean at v0.6.36 (and likely earlier — the v0.4.220 lexer change at line 395 added a `<digits>e<digits>` path that closed this finding as a side-effect; the per-finding date suggests the probe filed it before re-running against the patched lexer).
---

## Verification (main agent v0.6.36)

Built and ran the canonical repro from the finding:

```nucleor
fn main() -> i32 {
    let a: f64 = -1.0;
    let b: f64 = -1e10;
    print_f64(b);
    0
}
```

Output: `-10000000000.000000` (correct — IEEE 754 representation
of `-1.0e10`). Build clean, exit 0.

The lexer at `compiler/nucleor_s1_compiler.nr:395-434` handles
`<digits>e<digits>` directly as a token-kind-124 (raw-bits f64
literal), routed through `str_to_f64` for full IEEE-754 precision.
parse_unary wraps it in kind-5 (unary minus), and type_expr for
kind 5 returns the inner type (f64) cleanly.

## Root cause (historical)

The v0.4.220 scientific-notation lexer change closed the
fractional case (`1.0e10`) but left the bare-digit case
(`1e10`) lexing as `int 1` + `ident e10`. The lexer block at
`compiler/nucleor_s1_compiler.nr:395-434` was added later (see
the comment "Closes part of probe finding 2026-05-01-float-to-
int-cast-out-of-range-silent-ub" at line 395) — that side-fix
also closed this finding.

## No fixture added (already-passing case)

There's no value in adding a negative fixture for an already-
working case. Promoting as historical closure for the probe's
inbox audit trail.

## Promoted

- Fix shipped: pre-existing as of v0.6.36 (probably earlier;
  exact lex-line attribution is documented inline at the
  lexer block).
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
