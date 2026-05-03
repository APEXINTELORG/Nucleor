---
title: i32 binop result silently widens to i64 when used directly (not via let-binding) — `print_int(i32_max + 1)` outputs 2147483648 (out-of-range i32) instead of trapping or wrapping
severity: silent-miscompute (narrowing not enforced in expression context)
probe_file: probes/numeric/i32_div_by_neg_one.nr (probe-branch)
diagnostic_actual: pre-fix — i32 binop result propagates as i64 in expression position
diagnostic_expected: either narrow at every i32 use site (matching let-binding behavior at line 17108), OR fire compile-time TYP-NNN, OR runtime trap matching the documented strict-arith model
discovered_against: v0.4.204 + 14-ship probe-prep stack on commit 9fcb2d0
commit: 9fcb2d0
status: DOC-ONLY — narrowing in expression position requires walking every kind-7 (call), kind-4 (binop), and kind-9 (return) site to inject narrow_via_as. That's a cross-cutting refactor better landed in a dedicated ship cycle. Sister to `2026-05-01-box-new-literal-doesnt-propagate-T` (both are type-context-propagation gaps).
---

## Closure (analysis-only — no compiler change)

`narrow_via_as` is called on let-stmt only (line ~17108). When
the result of an i32 binop flows DIRECTLY into a fn arg, return
expr, or another binop without an intermediate let-binding, the
i32 narrowing is skipped — the LLVM `add i64` produces an i64
value that propagates uninterrupted.

### Sister findings (same workstream)

- `2026-05-01-box-new-literal-doesnt-propagate-T` — same family
  of "literal default to i32, narrowing happens at let-binding
  only" gaps.
- The v1 generic-inference / type-context-propagation pass
  closes both findings together.

### Adopter migration

```nucleor
// Pre-fix (i32 widens to i64 silently):
let a: i32 = 2147483647;
print_int(a + 1);            // outputs 2147483648 (out-of-range i32)

// Workaround — explicit narrow:
let a: i32 = 2147483647;
print_int((a + 1) as i32);   // outputs -2147483648 (wrap)
// OR via let:
let r: i32 = a + 1;
print_int(r);                 // narrow happens at let-binding
```

The let-binding workaround matches what the existing
`tests/features/overflow_trap.nr` test exercises.

## Forward-roadmap

The fix requires injecting `narrow_via_as` at every point where
an i32-typed expression is consumed in a non-i32 context. That's
a kind-7 / kind-4 / kind-9 walker; the type-checker already
knows the expression's type, so the lower path needs to consult
the types and emit narrowing where context-vs-source-type
mismatch.

## Promoted

- No code change.
- Promoted: 2026-05-03 by main agent.
