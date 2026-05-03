---
title: v0.6.19 RFC-0034 first-pass `[]` compile-time parameter parser ships, accepting `fn f[N: usize](x) -> ...` declarations and erasing them. Three residual edges remain — (1) calling with explicit CT argument `f[42](x)` SEGFAULTs at runtime; (2) negative literal default for `usize` accepted silently; (3) struct decls don't accept `[]` CT params.
severity: silent-miscompute → SEGFAULT (gap 1, rc=139); silent-miscompute (gap 2); parse-rejection (gap 3)
probe_file: probes/types/rfc0034_ct_param_residuals.nr (probe-branch)
diagnostic_actual: per-gap behavior in finding
diagnostic_expected: per-gap clean diag or proper implementation
discovered_against: main v0.6.19 (probe rebased)
commit: probe (post-rebase) + main 998ad04
status: DOC-ONLY — RFC-0034 first-pass-only is the documented v0.6 boundary. The full RFC-0034 implementation (call-site specialization, struct CT params, semantic environment) is the dedicated v1 cycle. Each gap below has a workaround today.
---

## Closure (analysis-only — no compiler change)

### Gap 1 — explicit CT-arg call SEGFAULTs

`ct_inc[42](x)` parses as `name[index_expr](call_args)` —
which the compiler reads as "index `ct_inc` by 42, then call
the result." The result of indexing a fn-name is invalid IR;
runtime SEGFAULTs.

Forward-roadmap: detect at parse_postfix the
`identifier[expr](args)` shape when `identifier` resolves to a
fn name; emit a clean diag "explicit CT-arg call form not
supported in RFC-0034 first-pass; omit the `[N]` and let the
default erase."

### Gap 2 — negative usize default silently accepted

`fn f[N: usize = -1]` — the default-value skipper
(`skip_compile_time_param_default`) consumes the `-1` token
sequence without type-checking. The default value is erased,
so the negative literal never affects runtime semantics —
but the parse-time accept hides the typo.

Forward-roadmap: validate the default literal against the
declared CT-param type (kind-1 negative int rejected for
unsigned types).

### Gap 3 — struct CT params NR020

`struct Buf[N: usize] { ... }` — the parse_struct_decl path
doesn't accept `[]` CT params (only `<>` generic params via
parse_struct_decl's existing parse_type substrate). NR020.

Forward-roadmap: extend parse_struct_decl with a pre-block
`skip_compile_time_params` call (matching the fn-decl
precedent at line ~970).

## Adopter migration

```nucleor
// Gap 1 — pre-fix SEGFAULT:
fn ct_inc[N: usize](x: i64) -> i64 { return x + 1; }
let r: i64 = ct_inc[42](5);    // SEGFAULTs

// Workaround — drop the [N] (it erases anyway in first-pass):
fn ct_inc[N: usize](x: i64) -> i64 { return x + 1; }
let r: i64 = ct_inc(5);    // works

// Gap 2 — pre-fix silent accept:
fn f[N: usize = -1] { ... }    // accepted, default erased

// Workaround — none needed; the default is erased anyway.

// Gap 3 — pre-fix NR020:
struct Buf[N: usize] { data: Vec<i64> }    // NR020

// Workaround — drop the [N] from struct decl (erase pattern):
struct Buf { data: Vec<i64> }
```

## Promoted

- No code change.
- Promoted: 2026-05-03 by main agent.
