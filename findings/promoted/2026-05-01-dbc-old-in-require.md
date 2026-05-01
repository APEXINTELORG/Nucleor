---
title: `#[require(old(x) > 0)]` — `old()` is meaningless in `#[require]` (no "before" snapshot exists yet) but emits the same misleading clang-link "undefined function `old()`" error as the undefined-ident finding
severity: wrong-error (semantic violation reported at wrong phase + as wrong error)
probe_file: probes/_sweep/dbc_old_in_require.nr (will be filed)
diagnostic_actual: clang-link error[TYP-005] "undefined function `old()`"
diagnostic_expected: clean parse-time halt — e.g. `error[CONTRACT-005]: 'old(...)' is only valid inside '#[ensure]' (postconditions). '#[require]' runs BEFORE the function body, so there is no prior state to snapshot. Move the check into '#[ensure]' or compare directly against the parameter.`
discovered_against: probe/exploration tip + main v0.4.252 RFC-0006 DbC ships
commit: probe 099767e + main 02752c1
---

## Repro

```nr
#[require(old(x) > 0)]
fn f(x: i64) -> i64 { x }

fn main() -> i32 {
    print_int(f(5) as i32);
    0
}
```

## Actual

Same misleading clang-link error as the undefined-ident sister finding:
```
error[TYP-005]: undefined function `old()`. Check spelling, or import the rod that defines it. (raised at clang link; type-checker emitted a TYP-005 warning earlier in this build.)
COMPILE FAILED (clang exit 1)
```

## Why this is a different finding

The undefined-ident finding (sister) is about ANY undefined identifier in a contract expression. This finding is specifically about `old()` — the canonical RFC-0006 construct — being used in the wrong attribute position (`#[require]` instead of `#[ensure]`). Adopters porting Eiffel/Ada/JML DbC code or learning RFC-0006 from the changelog might reasonably try `old()` in `#[require]`; the diagnostic should explain the semantic mismatch, not pretend `old()` is an undefined function.

## Suspected fix

In the contract-expression parser, after identifier-resolution lookup (per the sister finding):
1. Recognize `old(<inner>)` as a contract pseudo-fn.
2. If the enclosing attribute is `#[require]`: emit CONTRACT-005 ("old() not valid in preconditions") at parse time.
3. If `#[ensure]`: route to the v0.4.251 snapshot machinery.
4. If `#[invariant]`: emit CONTRACT-006 ("old() not valid in invariants" — same reason: invariants check before AND after, no single "old" point).

## Memory-blow-up note

Not memory-related.

## Cross-ref

- v0.4.251 — old(expr) snapshot in #[ensure]; this is the inverse case
- Sister finding: 2026-05-01-dbc-undefined-ident-in-contract-expr.md

## Probe

Filed alongside this finding.


## Promoted

- Fixture: `tests/err/err_contract_old_in_require.nr`
- Verify gate step: `t_rfc0006_old_in_require_reject` — exit 1 + CONTRACT-010 + fn name reference.
- Fix shipped: v0.4.277 — text-level word-boundary scan in the require pre-pass. New helper `contract_text_uses_old(text)` matches `old(` (preceded by start-of-text or non-ident char, followed by `(`) so `older` / `bold(` do not trigger. Halt with CONTRACT-010 naming the fn and workaround.
- Diag code: probe finding suggested CONTRACT-005 / -006 (already taken). Reserved CONTRACT-010 in spec doc + is_known_diag_code + verify scripts.
- Promoted: 2026-05-01 by main agent (from probe-agent prep on origin/probe/exploration commit ed85843)
