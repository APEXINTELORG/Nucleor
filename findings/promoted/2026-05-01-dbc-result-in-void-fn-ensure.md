---
title: `#[ensure(result == 0)]` on a void fn silently accepts — `result` is meaningless when the fn has no return type
severity: silent-miscompute / wrong-error class
probe_file: probes/dbc/dbc_result_in_void_fn.nr (will be filed)
diagnostic_actual: silent — build succeeds; ensure runs against an uninitialized 0-cell
diagnostic_expected: parse-time CONTRACT-007 ("'result' is not valid in '#[ensure]' on a void fn — no return value to reference")
discovered_against: main v0.4.246 (#[ensure] LIVE — CONTRACT-002)
commit: probe ed85843 + main 02752c1
---

## Repro

```nr
#[ensure(result == 0)]
fn void_fn(x: i64) {
    print_int(x as i32);
}

fn main() -> i32 {
    void_fn(5);
    0
}
```

## Actual

Build succeeds silently. Run prints `5`, exits 0. The `#[ensure]` check happens — but `result` resolves to whatever the void return register holds at fn exit (typically the alloca's zero-init), which is 0, so the ensure happens to pass by coincidence.

If the user wrote `#[ensure(result > 0)]` instead, ensure would fail with CONTRACT-002 — an EVEN MORE confusing situation, since the user's mental model is "this fn doesn't return a value; what's `result`?"

## Hazard tier

Sibling to Ship 42's vec_pop void-coerce-to-zero close. Both surface a void value as silently-0-coerced through the i64-everywhere ABI. Ship 42 closed `let x = void_fn()`; this finding is the contract-attribute equivalent.

## Suspected fix

In the contract-expression parser, when type-checking a `#[ensure]`:

1. Look up the fn's declared return type.
2. If return type is empty or "void" or unit:
   - Walk the contract expression for any reference to the keyword `result`.
   - If found: emit CONTRACT-007 ("'result' is not valid in '#[ensure]' on a void fn — fn `<name>` has no return value to reference. Remove the result reference, or change `<name>` to return a value if you need to assert on its output.")

3. Else: type-check `result` as the fn's return type (existing behavior).

This is a single-pass identifier check at contract-emit time. Same machinery as the dbc-undefined-ident finding's recommended fix.

## Memory-blow-up note

Not memory-related.

## Cross-ref

- Ship 42 (vec_pop void-coerce-to-zero close) — sister hazard family
- 2026-05-01-dbc-undefined-ident-in-contract-expr.md — same parse-time identifier-validation infrastructure needed
- v0.4.246 — #[ensure] LIVE; this is the validation gap

## Probe

`probes/dbc/dbc_result_in_void_fn.nr` (filed alongside this finding).


## Promoted

- Fixture: `tests/err/err_contract_result_in_void_fn.nr`
- Verify gate step: `t_rfc0006_result_in_void_fn_reject`
- Fix shipped: v0.4.272 — single-pass identifier scan in the dbc preamble. When `fn_return_type(source, ens_name)` returns `""` (void fn) AND `ensure_text_uses_result(ens_text)` returns 1, halt with CONTRACT-008.
- Diag code: probe finding suggested CONTRACT-007 but that slot is reserved for cert profile static-proof; reserved CONTRACT-008 for this in spec doc + is_known_diag_code + verify scripts.
- Promoted: 2026-05-01 by main agent (from probe-agent prep on origin/probe/exploration commit e101dc0)
