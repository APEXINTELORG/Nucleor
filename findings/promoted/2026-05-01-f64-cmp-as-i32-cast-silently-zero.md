---
title: `(f64_cmp) as i32` in expression context silently returns 0 regardless of comparison result. Workaround `let v: bool = …; v as i32` works. The bool result of an f64 comparison is dropped/zeroed during direct as-cast lowering. Affects ALL f64-cmp-direct-cast adopter patterns (loop bounds, bitmasks, ML inference toggles).
severity: silent-miscompute (CRITICAL — comparison results silently zero in widespread idiom)
probe_file: probes/numeric/f64_cmp_as_i32.nr (will be filed)
diagnostic_actual: build + run succeed; `(1.5 < 2.5) as i32` returns 0 (should be 1)
diagnostic_expected: build + run produce 1 (the bool result of `1.5 < 2.5` is `true`, cast to i32 = 1)
discovered_against: main v0.5.25 (probe rebased)
commit: probe (post-rebase) + main 2fe41ef
---

## Repro

```nr
fn main() -> i32 {
    let a: f64 = 1.5;
    let b: f64 = 2.5;
    print_int((a < b)   as i32);   // 0 ❌ (expected 1)
    print_int((a == 1.5) as i32);  // 0 ❌ (expected 1)
    print_int((1 < 2)    as i32);  // 1 ✓ (control: i64 cmp works)
    print_int((1 == 1)   as i32);  // 1 ✓ (control)
    print_int(((a < b) || false) as i32);  // 0 ❌ (bug propagates through ||)
    let v: bool = a < b;
    print_int(v as i32);            // 1 ✓ (let-binding workaround)
    0
}
```

Output:
```
0
0
1
1
0
1
```

## Critical context

The if-branch path works correctly — `if (a < b) { … } else { … }` selects the right branch:

```nr
if (a < b) { print("LT\n"); } else { print("GE\n"); }   // prints "LT" ✓
```

So the **f64 comparison itself produces the right bool**. The bug is specifically in **lowering `bool as i32` when the bool came directly from an f64 comparison without an intermediate let-binding**.

## Affected idioms

Every adopter pattern that sums / counts / masks based on f64 comparisons:

```nr
// Counting NaN-free entries in a Vec<f64>
let mut count: i32 = 0;
for x in &v { count = count + (*x == *x) as i32; }    // ← always 0 (NaN check too)

// Loop continuation flag
let active: i32 = (energy > threshold) as i32;        // ← always 0

// Bitmask
let flags: i32 = ((a > 0.0) as i32) | (((b > 0.0) as i32) << 1);  // ← always 0
```

Numerical algorithms (sorting on f64, binary search, optimization step gates, ML inference threshold checks) are silently broken.

## Hazard tier

**Critical silent-miscompute, semantic class.**

This is the worst kind of compiler bug — the program runs to completion, no diagnostic, no panic, output is plausibly-shaped (just wrong). Adopters notice when downstream computation is "off" but tracing back to an `as i32` cast is hard.

The let-binding workaround is non-obvious. Adopter has to know that `(f64_cmp) as i32` is broken but `let v: bool = f64_cmp; v as i32` works.

## Suspected fix

In `compiler/nucleor_s1_compiler.nr` `lower_expr` for kind 99 (as-cast):
- When the source expression is a kind-4 (binop) with `op` in `{LT, LE, GT, GE, EQ, NE}` and the operands are `f64` typed
- The current path likely lowers as-cast on the wrong type (perhaps zero-extending `i1` from the wrong operand, or producing `fcmp` then ignoring the result and emitting `i32 0`)
- The let-bound path lowers correctly because `let v: bool = …` triggers a known-good bool storage allocation, then `v as i32` reads the stored bool and zero-extends.

Fix candidate: in the as-cast lowering path, when the source is `bool`, check whether the bool came from an f64 comparison kind. If so, ensure the `i1` from `fcmp` is properly zero-extended to `i32`. Likely a 1-shape match in the as-cast lowering.

Alternatively: if the f64-cmp is being lowered with a separate output-pruning path (e.g. unused-result optimization treats bool-result-of-f64-cmp as unused), guard the as-cast consumer.

## Memory-blow-up note

Not directly memory-related, but the pattern is exactly the kind of silent-miscompute that produces wrong-but-plausible numbers — adopter algorithms that gate memory allocations on f64 conditions can either over-allocate (when actual cmp would gate) or under-allocate (segfaults from missing capacity). Indirect memory hazard.

## Cross-ref

- `2026-04-30-i32-binop-no-narrow-in-expression-context.md` — sister type-narrow-loss-in-expression-context family
- `2026-05-01-num-019-coverage-gap-binop-vs-literal.md` — sister type-context-loss family
- v0.4.NNN narrow_via_as machinery — same lowering layer that handles widening

## Probe

`probes/numeric/f64_cmp_as_i32.nr` — minimal repro.


## Promoted

- Fix shipped: v0.5.27 — `binop_float_type` (s1 line ~19396)
  now returns "" (not float) when the binop is a comparison
  or logical operator (`<` `>` `<=` `>=` `==` `!=` `&&` `||`).
  The result of a cmp/logic op is bool/i64, regardless of
  operand type.
- Pre-fix path: `(a < b)` for `a, b: f64` had
  `binop_float_type` returning "f64" → kind-99 (as cast)
  dispatched `f64_to_i32` on the i64 cmp-result bit pattern
  (always 0 or 1) → produced 0 because the saturating cast's
  small-magnitude path returned 0/wrong-result.
- Now: cmp/logic binops fall through to the int→int
  `as_i32`/`as_i64` helper which correctly produces 0/1.
- Fix is one new branch (3 lines) in `binop_float_type`.
- Validation: probe's repro now outputs `1 1 1 1 1 1` (was
  `0 0 1 1 0 1`). Round-1 == round-2 IR fixed-point at sha256
  `81be5e714ca04e9bdb0801546eeeece2750884167bd76094e81eafbc8ce7d57a`.
- Adopter idioms unblocked: counting NaN-free entries via
  `(*x == *x) as i32`, loop continuation flags via
  `(energy > threshold) as i32`, comparison-driven bitmasks.
- Sister code paths checked (line ~17122-17123 binop_float_type
  on integer add/sub/mul/div lower path): unaffected — that
  path already does the cmp/logic disambiguation by routing
  cmp ops to the integer-cmp lower (icmp eq/lt/gt etc.).
- Promoted: 2026-05-01 by main agent (probe commit 83a6aa6).
