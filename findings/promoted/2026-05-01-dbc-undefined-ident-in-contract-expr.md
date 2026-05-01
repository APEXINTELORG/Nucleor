---
title: `#[require(undefined_var > 0)]` — undefined identifier in contract expression silently passes type-check, fails at clang link with misleading "undefined function" message
severity: wrong-error (parse-time → clang-link phase mismatch)
probe_file: probes/_sweep/dbc_undefined_in_contract.nr (will be filed)
diagnostic_actual: error[TYP-005] at clang link with "undefined function `undefined_var()`" — but `undefined_var` was used as a value, not a fn call
diagnostic_expected: clean compile-time halt naming the contract attribute and the undefined identifier (e.g. `error[CONTRACT-VAL-001]: '#[require]' expression references undefined identifier 'undefined_var'. Pre-conditions can only reference fn parameters and module-level constants.`)
discovered_against: probe/exploration tip + main v0.4.252 RFC-0006 DbC ships
commit: probe 099767e + main 02752c1
---

## Repro

```nr
#[require(undefined_var > 0)]
fn f(x: i64) -> i64 { x }

fn main() -> i32 {
    print_int(f(5) as i32);
    0
}
```

## Actual

```
error[TYP-005]: undefined function `undefined_var()`. Check spelling, or import the rod that defines it. (raised at clang link; type-checker emitted a TYP-005 warning earlier in this build.)
COMPILE FAILED (clang exit 1)
```

The diagnostic text is **misleading on two axes**:

1. **Wrong identifier kind**: `undefined_var` was written as a VALUE in `> 0` comparison, not a fn call. The "undefined function `undefined_var()`" text suggests the user typo'd a call site.

2. **Wrong phase**: error fires at clang link, not at parse/type-check. v0.4.245 (CONTRACT-001) ships the contract substrate but doesn't validate identifiers in contract expressions before lowering. The type-checker emits TYP-005 as a warning earlier (per the message text), but the build proceeds; clang then fails with a baffling reference to a synthesized fn name.

## Hazard tier

Same family as `closure-cant-call-sibling-closure` (closed by Ship 37) — a contract expression's identifiers should be type-checked at parse time, before the IR substrate emits unresolved symbols. Currently the contract expression goes from source-text → IR call site without intermediate validation.

## Suspected fix

In the contract-expression parser (the source-text scanner added in v0.4.244), validate that every identifier in the expression resolves to:
1. A fn parameter (for `#[require]` and `#[ensure]`)
2. A module-level constant
3. The reserved name `result` (for `#[ensure]`)
4. The reserved name `self` and field access via `self.<name>` (for `#[invariant]`)
5. A whitelisted runtime helper (str_len, vec_len, etc.)

Anything else → halt at parse time with a contract-specific diagnostic that names the actual problem.

## Memory-blow-up note

Not memory-related. Wrong-error class.

## Cross-ref

- Ship 37 (closure-sibling-call halt) — same wrong-phase pattern
- v0.4.244 — RFC-0006 DbC source-text scanner; doesn't run type-check on contract expressions
- v0.4.245-252 — DbC ships that built on top of the unchecked substrate

## Probe

Filed alongside this finding.


## Promoted

- Fixture: `tests/err/err_contract_undefined_ident.nr`
- Verify gate step: `t_rfc0006_undefined_ident_reject` — exit 1 + CONTRACT-011 + the named bad ident.
- Fix shipped: v0.4.283 — token-walk scan in the require pre-pass via new `find_unbound_ident_in_contract(source, fn_name, predicate)` helper. Walks the predicate text char-by-char extracting bare idents, applies skip rules: followed by `(` (fn call), `::` (path), `[` (index), `{` (struct-init); preceded by `.` (field/method) or `::` (path tail); DbC keyword allowlist (`result`, `old`, `self`, `true`, `false`, `null`, `Some`, `None`, `Ok`, `Err`); CamelCase first char (Type / Variant / Module name); fn parameter via `fn_param_type()`. Anything that survives all skips is reported as the unbound ident.
- Diag code: probe finding suggested an unspecified slot. Reserved CONTRACT-011 (next free in CONTRACT series after CONTRACT-010 from v0.4.277) in `is_known_diag_code` + spec doc + verify scripts.
- Coverage scoping: catches the canonical bare-ident-as-value case (`#[require(undefined_var > 0)]`). Does NOT catch idents inside fn calls, paths, field accesses, struct-inits, or after `::` — those are valid resolution paths handled by other passes. False-negative bias preferred over false-positive (better to miss a typo than reject valid code).
- Probe inbox at v0.4.283 main: 0 active findings remaining (eight CLOSED this session via promotions; this is the ninth and last).
- Promoted: 2026-05-01 by main agent (from probe-agent prep on origin/probe/exploration commit ed85843)
