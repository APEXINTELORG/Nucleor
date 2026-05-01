# Upgrading to v0.4.239

**TL;DR — if you're on v0.4.238, upgrade to v0.4.239 immediately.**
v0.4.238 had a critical bug where `wrapping { ... }` blocks
panicked at runtime on real overflow. v0.4.239 fixes it. Most
other adopters are unaffected by this upgrade.

## What changed across v0.4.232 → v0.4.239

The v0.5 residual punchlist closed in this window, with one
breaking-default change and one critical bug fix.

### Default-on strict integer arithmetic (v0.4.238)

`+`, `-`, `*` on signed integer types (`i8`, `i16`, `i32`, `i64`)
now **panic on overflow** by default — previously they wrapped
silently. This matches Rust debug-build behavior and catches a
class of silent miscomputes.

**You're affected if** any of your code does signed integer
arithmetic that may overflow at runtime, AND the wrap was
intended (not a bug).

**Three escape hatches:**

1. **`wrapping { ... }` block** — wrap the arithmetic in
   `wrapping { ... }`; per-op behavior reverts to native LLVM
   modular arithmetic, no traps. Best for explicit
   wrap-on-overflow semantics in a contained scope.
   ```nucleor
   let x: i32 = 2147483647;
   let y: i32 = wrapping { x + 1 };  // y = -2147483648, no panic
   ```

2. **`saturating { ... }` block** — clamp on overflow to the
   type's max/min. Best when an arithmetic spike should pin to
   a sensible boundary instead of panicking.
   ```nucleor
   let x: i64 = 9223372036854775000;
   let y: i64 = saturating { x + x };  // y = i64::MAX, no panic
   ```

3. **Compile-time opt-out** — set `NUCLEOR_INT_STRICT_INTRIN=0`
   when invoking the compiler:
   ```bash
   NUCLEOR_INT_STRICT_INTRIN=0 nucleor build src.nr -o app
   ```
   This restores the pre-v0.4.238 behavior (silent wrap on
   overflow via LLVM `add nsw`). Use only if your codebase has
   too many overflow-tolerant sites to convert in one ship.

### `wrapping { ... }` was broken in v0.4.238 (fixed in v0.4.239)

A parser bug in v0.4.238 caused `wrapping { ... }` blocks to
emit the strict-intrinsic trap path despite the user explicitly
opting into wrap behavior. Real overflows inside `wrapping {}`
panicked instead of wrapping. v0.4.239 fixes this.

If you upgraded to v0.4.238 and deployed code using
`wrapping {}`:
- **Symptom:** runtime panic with `PANIC: integer overflow`
  (exit 1) where the user's code expected a wrapped value.
- **Workaround on v0.4.238:** set
  `NUCLEOR_INT_STRICT_INTRIN=0` to disable strict mode entirely
  (effective but loses the safety benefit on the rest of the
  codebase).
- **Fix:** upgrade to v0.4.239 or later.

## What didn't change

- `wrapping { ... }` and `saturating { ... }` block syntax —
  identical to pre-v0.4.238.
- Unsigned arithmetic semantics — unchanged at the surface
  (some internal IR-shape adjustments are tracked for v0.4.240,
  see CHANGELOG).
- All non-arith operators (comparison, shift, bitwise) —
  unchanged.
- Division and modulo (`/`, `%`) — already trap on divide-by-
  zero per v0.4.95; unchanged.
- The escape hatches — `wrapping { }` and `saturating { }` blocks
  have always existed; the v0.4.238 default flip just made them
  the standard idiom for wrap-tolerant code instead of being
  rare opt-ins.

## Audit checklist for upgrading

Run this against your codebase once before upgrading:

1. **Search for arithmetic that may overflow at runtime.**
   Common patterns:
   - Sum-accumulation loops (`total = total + x` on growing
     inputs).
   - Bit-packing (`(hi << 32) | lo` where `hi` is i64).
   - Subtraction near zero (`size = a - b` where `b > a` is
     possible).
   - Multiplication (`area = w * h` for large w, h).

2. **For each site, decide:**
   - Was the wrap intended? → wrap it in `wrapping { ... }`.
   - Should it pin to max/min instead? → wrap it in
     `saturating { ... }`.
   - Was the overflow a bug? → leave it alone; the panic is the
     correct new behavior.

3. **For migration in chunks**, set
   `NUCLEOR_INT_STRICT_INTRIN=0` at compile time during the
   transition; convert each module incrementally; remove the
   env var once done.

## Quick sanity test

After upgrading:

```nucleor
fn main() -> i32 {
    let max: i32 = 2147483647;
    let wrapped: i32 = wrapping { max + 1 };
    if wrapped != -2147483648 { return 1; };
    print("OK upgrade verified");
    0
}
```

Should print `OK upgrade verified` and exit 0. If it panics,
you're on v0.4.238 (broken) — upgrade to v0.4.239.

## Reference

- Full v0.4.232 → v0.4.239 changelog: `CHANGELOG.md`
- v0.5 punchlist closure: `docs/milestones/v0.5_RESIDUAL_SEQUENCING_2026-04-30.md`
- Strict-mode design rationale: `docs/rfcs/RFC-0015-numeric-types.md`
- Track B intrinsic substrate: `docs/milestones/spikes/track_b_3e1_spike_2026-04-30.md`
- Track E precedence + narrow validation:
  `docs/milestones/spikes/track_e_3e1_narrow_validation_2026-04-30.md`
- Track F perf data:
  `docs/milestones/spikes/track_f_perf_3e3_decision_2026-04-30.md`
