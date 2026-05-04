---
title: NUM-G2 — math_abs(i64::MIN) returns i64::MIN under NUCLEOR_INT_STRICT_INTRIN=0; math_gcd and math_pow_int inherit silently
severity: silent-miscompute
probe_file: probes/numeric/num_g2_math_abs_imin.nr
diagnostic_actual: build clean; runtime returns negative i64 (math_abs identity violation); rc=0
diagnostic_expected: panic (matches strict-mode policy) OR saturate to i64::MAX with explicit choice documented
discovered_against: v0.4.180
commit: 03fa84fe
status: NEW
---

## Repro

```nr
import "stdlib/rods/math.nr"

fn main() -> i32 {
    let imin: i64 = -9223372036854775807 - 1;     // i64::MIN

    // case 1 — direct math_abs miscompute
    let r1: i64 = math_abs(imin);
    print_int(r1);
    if r1 < 0 { print("BUG: math_abs returned negative"); }

    // case 2 — math_gcd inherits via internal math_abs call
    let g: i64 = math_gcd(imin, 7);
    print_int(g);

    // case 3 — math_pow_int unchecked multiply wraps
    let p: i64 = math_pow_int(2, 63);
    print_int(p);

    return 0;
}
```

## Actual (under NUCLEOR_INT_STRICT_INTRIN=0)

```
$ NUCLEOR_INT_STRICT_INTRIN=0 bin/nucleor.exe build probes/numeric/num_g2_math_abs_imin.nr
  ... clean build, no diagnostic
$ ./target/num_g2_math_abs_imin.exe
math_abs(i64::MIN):
-9223372036854775808
BUG: math_abs returned negative
math_abs(i64::MAX):
9223372036854775807
math_abs(-1):
1
math_gcd(i64::MIN, 7):
-1
math_pow_int(2, 63):
-9223372036854775808
rc=0
```

Three concrete failures in one run:

- `math_abs(i64::MIN)` returns `i64::MIN` itself (negative) — violates the implicit "result is non-negative" contract.
- `math_gcd(i64::MIN, 7)` returns `-1` (negative GCD).
- `math_pow_int(2, 63)` silently wraps to `i64::MIN` with no signal.

## Actual (under default NUCLEOR_INT_STRICT_INTRIN=1, for comparison)

```
$ bin/nucleor.exe build probes/numeric/num_g2_math_abs_imin.nr
$ ./target/num_g2_math_abs_imin.exe
math_abs(i64::MIN):
PANIC: integer overflow
rc=1
```

Loud failure — adopter sees the trap. So the bug is **configuration-dependent**: any code path compiled with `NUCLEOR_INT_STRICT_INTRIN=0` (perf-tuned ML, hot loops, anywhere the user wants to suppress runtime overflow checks) silently cascades through `math_abs` / `math_gcd` / `math_pow_int` / `math_lcm`.

## Source review

`stdlib/rods/math.nr:9-12`:

```nr
fn math_abs(n: i64) -> i64 {
    if n < 0 { return 0 - n; };
    return n;
}
```

`0 - i64::MIN` overflows. In non-strict mode the `sub` is plain LLVM `sub i64`, two's-complement wraps, and the result is `i64::MIN` again — still negative.

`stdlib/rods/math.nr:30-40`:

```nr
fn math_pow_int(base: i64, exp: i64) -> i64 {
    if exp < 0 { return 0; };
    if exp == 0 { return 1; };
    let mut result: i64 = 1;
    let mut i: i64 = 0;
    while i < exp {
        result = result * base;
        i = i + 1;
    };
    return result;
}
```

`result * base` is unchecked. Loop overshoots i64 range with no signal in non-strict mode.

`stdlib/rods/math.nr:54-60`:

```nr
fn math_gcd(a: i64, b: i64) -> i64 {
    let mut x: i64 = math_abs(a);
    ...
}
```

Direct inheritance: math_abs miscompute flows into the gcd state.

## Severity

**silent-miscompute** under `NUCLEOR_INT_STRICT_INTRIN=0`. Since the strict-mode default is "1" (verified at `compiler/nucleor_s1_compiler.nr:7385` — `env_get_or("NUCLEOR_INT_STRICT_INTRIN", "1")`), most users hit the panic path. But:

1. Adopter perf paths frequently disable strict-mode in compile flags.
2. The strict-mode env var is consulted at compile time and folded into the cache key (RFC NUM-G2 cross-cutting note); it is not a per-function or per-block annotation. A whole compilation unit either has it or doesn't.
3. There is no `#[strict_arith]` per-function override (RFC notes Phase 4 wants this).

The hazard is real and downstream code (e.g. ML hyperparameter loops calling `math_pow_int` with adversarial inputs, range arithmetic calling `math_abs` on differences that might cross i64::MIN) silently produces wrong outputs.

## Suggested fix

Per RFC NUM-G2 Phase 1: pick one of two policies and document it. Both candidates:

```nr
fn math_abs(n: i64) -> i64 {
    if n == -9223372036854775807 - 1 {  // i64::MIN
        // Option A — panic in non-strict too
        panic("math_abs(i64::MIN) is undefined; use saturating_abs or wrapping_abs");
        // Option B — saturate
        return 9223372036854775807;     // i64::MAX
    };
    if n < 0 { return 0 - n; };
    return n;
}
```

RFC recommends panic (Option A) to match strict-mode philosophy; an explicit `wrapping_abs` / `saturating_abs` companion gives the user the choice.

Same surgical fix for `math_pow_int`: replace `result * base` with `checked_mul` returning `Option<i64>` OR add explicit overflow check that panics.

`math_gcd` and `math_lcm` close as a side-effect once `math_abs` is fixed.

## Cross-ref

- `stdlib/rods/math.nr:9-12` (math_abs), `:30-40` (math_pow_int), `:54-60` (math_gcd), `:66-69` (math_lcm)
- RFC NUM-G2 in `docs/rfcs/gap-analyses/Nucleor_Numeric_Correctness_Gap_Analysis_and_RFC_2026-05-04.md`
- Cross-cutting risk: env-controlled strict-mode is global, no per-fn override
- Companion finding: NUM-G1 (different miscompute, same env-flag-controlled discipline)

## Notes for main agent

Recommend a Phase 1 ship that closes math_abs / math_pow_int / math_gcd / math_lcm in a single small patch. This is a 30-line fix that converts a launch-blocker silent-miscompute class into a clean panic. The wrapping_abs / saturating_abs companions are useful but not blocking — adopters who really want wrapping can write `0 - n` inline.

The bigger question is the env-controlled strict-mode discipline: even after these fixes, the underlying NUM-G2 cross-cutting risk (adopter perf code with strict_intrin=0 silently miscomputing across the entire numeric stdlib) remains. The right closure is RFC Phase 4 per-fn `#[strict_arith]` annotation. That's a v1.x project; the four-fn patch above is v1.0-eligible.
