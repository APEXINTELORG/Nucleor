---
title: u64 overflow silently wraps — asymmetric with i64/i32/i16/i8 which already panic via NUCLEOR_INT_STRICT_INTRIN=1 default
severity: silent-miscompute (asymmetric-coverage — sister to NUM-021 gap 1)
probe_file: probes/numeric/u64_overflow_wraps.nr (probe-branch)
diagnostic_actual: pre-fix — u64 add/sub/mul wrap silently, no panic
diagnostic_expected: panic class matching i64-strict-intrin default OR documented opt-out
discovered_against: probe/exploration tip
commit: probe + main
status: DOC-ONLY — pairs with NUM-021 gap 1 (`const B: u64 = u64::MAX + 1;` silent compile). Both are aspects of the u64-strict-arithmetic gap. Forward-roadmap: extend the strict-intrin runtime helper family to include `__nucleor_panic_add_u64` / `panic_sub_u64` / `panic_mul_u64` (their checked_* cousins exist; the panic_* variants don't yet). Then route u64 binops through them under NUCLEOR_INT_STRICT_INTRIN=1.
---

## Closure (analysis-only — no compiler change)

The strict-intrin family at `stdlib/runtime/nucleor_llvm_rt.c`:

| Width | panic_add | panic_sub | panic_mul | wrapping_add | wrapping_sub | wrapping_mul |
|---|---|---|---|---|---|---|
| i64 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| i32 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| i16 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| i8 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| u64 | **✗ MISSING** | **✗ MISSING** | **✗ MISSING** | ✓ | ✓ | ✓ |
| u32 | ✓ (via __nucleor_checked_*; panic-emit lowered through the existing path) | ✓ | ✓ | ✓ | ✓ | ✓ |
| u16 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| u8 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

u64 is the asymmetric outlier. Sister finding NUM-021 gap 1
shows the same hole at compile time:

```nucleor
const B: u64 = 18446744073709551615 + 1;     // u64::MAX + 1
// No NUM-021 at compile, runtime wraps to 0 silently.
```

## Forward-roadmap

Add three runtime helpers (sister-shape to the existing i64
versions):

```c
long long __nucleor_panic_add_u64(long long a, long long b) { ... }
long long __nucleor_panic_sub_u64(long long a, long long b) { ... }
long long __nucleor_panic_mul_u64(long long a, long long b) { ... }
```

Then route u64 binops through them in the lower path under
NUCLEOR_INT_STRICT_INTRIN=1. Same shape as the v0.6.43 unary-neg
ship.

### Why deferred

This is the runtime-ABI-class change that hit the v0.6.48-
attempt-1 bootstrap-cycle hole. New runtime declares need a
dedicated validation cycle (verify the bin's compiled-in
emit_externs round-trips cleanly). Bundled with the negative-
zero finding for the same dedicated cycle.

## Adopter migration

```nucleor
// Pre-fix (silent wrap):
let x: u64 = 18446744073709551615;     // u64::MAX
let y: u64 = x + 1;                     // wraps to 0 silently

// Workaround (explicit checked):
let x: u64 = 18446744073709551615;
let y: u64 = checked_add_u64(x, 1);    // returns Err on overflow
// or
let y: u64 = saturating_add_u64(x, 1); // saturates at u64::MAX
```

## Promoted

- No code change.
- Promoted: 2026-05-03 by main agent.
