---
title: v0.6.18 NUM-021 closes module-level `const` integer-overflow at compile time for i64 add/sub/mul, but four coverage gaps remain — (1) **u64 const overflow silently compiles**, (2) **`i64::MIN` literal `-9223372036854775808` false-fires NUM-021** (canonical Rust literal rejected), (3) **const-time div/mod by zero AND shift-out-of-range fall through to runtime PANIC** instead of NUM-021, (4) **`let x: i64 = i64::MAX + 1;` (let-binding with const expr) PANICs at runtime** rather than firing NUM-021 at compile time.
severity: silent-miscompute (gap 1, u64) + false-reject (gap 2, i64::MIN) + asymmetric-coverage (gaps 3 + 4)
probe_file: probes/numeric/num_021_coverage_gaps.nr (probe-branch)
diagnostic_actual: see "Repro matrix" — four distinct shapes
diagnostic_expected: NUM-021 fires at compile time on every const-overflowing-or-undefined integer expression regardless of width, op, and binding context. `i64::MIN` literal compiles cleanly.
discovered_against: main v0.6.18 (probe rebased)
commit: probe (post-rebase) + main d1eabeb
status: GAP 2 CLOSED in v0.6.49 — canonical i64::MIN literal now compiles. Gaps 1, 3, 4 remain open for follow-on ships.
---

## Closure (gap 2 — main agent v0.6.49)

`-9223372036854775808` (canonical Rust i64::MIN literal) now
compiles cleanly without false-firing NUM-021. The parser
tokenizes this as unary-minus applied to `9223372036854775808`;
the lexer wraps `2^63` (= 9223372036854775808) to i64::MIN at
storage time per the i64-everywhere ABI's wrap semantics. Pre-fix
the const evaluator's kind-5 unary-minus saw `0 - i64::MIN` and
flagged overflow without distinguishing the literal-wrap-from-source
case (where the result `-2^63 = i64::MIN` IS representable in i64)
from a compute-time `-i64::MIN` overflow.

Three coordinated changes (compiler/nucleor_s1_compiler.nr):

1. `const_i64_expr` kind-5: when inner is kind-1 literal AND value
   == i64::MIN, return i64::MIN (don't flag overflow).
2. `lower_expr` kind-5: same special-case at lowering layer — emit
   `ir_const_int(r, i64::MIN)` directly instead of `panic_neg(opr)`.
3. `str_to_int` final neg step: switch `0 - result` to
   `wrapping_sub(0, result)`. The const-tracker round-trips i64::MIN
   through `tenv_set_const_i64` / `tenv_get_const_i64`, hitting
   `str_to_int("-9223372036854775808")`. Pre-fix this panicked under
   strict-intrin; wrapping_sub preserves the bit pattern.

## Repro matrix — gap 2 (CLOSED)

| Form | Expected | Pre-v0.6.49 | v0.6.49 |
|---|---|---|---|
| `const B: i64 = -9223372036854775808;` | accept (i64::MIN) | NUM-021 false-fire | accept ✓ |
| `let x: i64 = -9223372036854775808;` | accept | NUM-021 false-fire | accept ✓ |
| `-x` where x holds i64::MIN at runtime | runtime panic | runtime panic | runtime panic ✓ (no change) |
| `const B: i64 = 9223372036854775807 + 1;` (i64::MAX + 1) | NUM-021 | NUM-021 | NUM-021 ✓ (no change) |

## Open gaps (forward-roadmap)

### Gap 1 — u64 const overflow silently compiles

```nr
const B: u64 = 18446744073709551615 + 1;     // u64::MAX + 1
```

Currently builds + runs clean (rc=0). NUM-021 const-eval path
operates on i64 arithmetic; u64 overflow on the i64 representation
isn't an i64 overflow at all (the bit pattern just wraps). Needs
a unsigned-aware const-eval pass.

### Gap 3 — const-time div/mod/shift fall through to runtime

```nr
const B: i64 = 1 << 64;
const C: i64 = 1 / 0;
const D: i64 = 5 % 0;
```

All three currently emit a binary that PANICs at runtime startup.
The const evaluator's binop branch covers add/sub/mul; div/mod/shift
need the same compile-time undefined-behavior detection.

### Gap 4 — let-binding with const expr at runtime, not compile time

```nr
fn main() -> i32 {
    let x: i64 = 9223372036854775807 + 1;   // i64::MAX + 1
    print_int(x as i32);
    return 0;
}
```

Currently emits a binary that PANICs at runtime startup with the
strict-intrin trap. The let-binding type-check at line ~17566 calls
`const_i64_expr` to track the value but doesn't fire NUM-021 on
overflow; only `type_check_global_consts` does (kind-50 only).
Needs to extend the let-binding path to also emit NUM-021 when
const_i64_overflow returns 1.

## Adopter migration

For gap 2 (now closed): the canonical Rust form works directly.
The pre-v0.6.49 workaround `(-9223372036854775807) - 1` still
works but is no longer needed.

## Promoted

- New fixture: `tests/fixtures/v0649_imin_literal_accepts.nr`.
- New verify step: `v0649_imin_literal_accepts`.
- Fix shipped: v0.6.49 (gap 2 only).
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
- Sister-gaps 1, 3, 4: tracked for follow-on ships.
