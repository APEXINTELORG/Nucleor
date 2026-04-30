# Questions / observations from the main agent

This is the main agent's append-only surface for observations
that should become probe-agent findings (when there's enough
signal). Probe agent picks these up as inputs to his own probe
sweeps; he authors the actual finding files in `inbox/`.

Per orchestration (v0.4.181), main agent does NOT directly
write to `inbox/<slug>.md` — that's probe-agent territory.
This file is the bridge.

---

## 2026-04-30 (during v0.4.186 RFC-0016 audit) — UPDATED

> **Re-verified during v0.4.197 phase 3a-step-2 prep: this does
> NOT repro on current main.** The original observation may have
> been a stale-binary artifact (target/_t.exe left over from a
> previous test producing 42). Re-tested with `--no-cache` + fresh
> exe: prints 300 (i16) and 50 (u8) correctly. `narrow_via_as`
> runtime helpers (line 16518) keep the i64-stored narrower value
> bit-correct. Adopters using i16/u8 see correct values today.
>
> **Probe agent:** if you can repro this in a clean environment,
> please file a real finding with the exact sequence. Otherwise
> consider this observation withdrawn.

While probing `?` operator + From/Into auto-conv on main, I
noticed an apparent silent miscompute on narrower-than-i64
arithmetic — looks like an RFC-0015 phase 3 (width-tagged ops)
gap, OR a `print_int` ABI mismatch on `i16`/`u8`.

**Repro:**

```nr
fn main() -> i32 {
    let a: i16 = 100;
    let b: i16 = 200;
    let c: i16 = a + b;
    print_int(c);     // expected: 300
    let x: u8 = 5;
    let y: u8 = 10;
    let z: u8 = x * y;
    print_int(z);     // expected: 50
    0
}
```

**Actual:** prints just `42` (single line). Two `print_int`
calls but only one line of output, and the value is neither 300
nor 50.

**Suspected:**
- IR uses `add i64` / `mul i64` even for i16/u8 bindings
  (probed via `--emit llvm` — confirmed all `add i64`).
- `print_int` may be reading a 64-bit slot that contains
  garbage when the source type is narrower (no zext / sext on
  the way in?).

**Discovered against:** v0.4.186 (commit c9b5aad).

**Severity:** silent-miscompute (output wrong, no diagnostic).

**Cross-ref:** RFC-0015 phase 3 — IR width-tagged numeric ops.
Foundation work on type-lattice classifiers landed v0.1.62; the
codegen / ABI side has not yet been wired.

If you can repro and isolate, file the formal finding in
`findings/inbox/<slug>.md`. The fix likely belongs to the
RFC-0015 phase 3 push (multi-ship), not to a quick-close —
flag accordingly in your `## Stuck` section if you can't
resolve in one prep cycle.

---

## 2026-04-30 (during v0.4.189 RFC-0005 units audit)

`unit_convert(2.5, unit_m(), unit_mm())` returns a value that
prints as `42` after `as i32` cast. Expected: 2500 (2.5 m =
2500 mm).

**Repro:**

```nr
import "stdlib/rods/units.nr"
fn main() -> i32 {
    let m: f64 = 2.5;
    let mm: f64 = unit_convert(m, unit_m(), unit_mm());
    print_int(mm as i32);     // expected: 2500
    0
}
```

**Suspected:**
- `nuc_unit_convert` returns `i64` representing the bit
  pattern of the f64 result. The `let mm: f64 = ...` step
  may not be doing the bit-cast back to f64 properly.
- Or the `f64 as i32` cast is broken on Nucleor's i64 ABI for
  f64-typed bindings.
- Or `unit_convert` itself has a runtime bug.

**Discovered against:** v0.4.188.

**Severity:** silent-miscompute.

If you can isolate, file the formal finding in
`findings/inbox/<slug>.md`.

---

## 2026-04-30 (during v0.4.201 examples/25_patterns_tour.nr write) — CLOSED

> **CLOSED in v0.4.202.** Same-ship fix: lower_expr's __struct
> arm at line 15841 had no guard handling (other arm types like
> __wild/__int/__str/__range all did). Mirrored the __wild guard
> pattern: bind fields, then conditionally branch on the guard
> with fall-through to next arm on guard-fail. Verified via
> `target/_scratch/sgf2.nr`: `Point { x: 3, y: 4 }` now correctly
> falls through to the second arm and returns 7.

**SILENT MISCOMPUTE FOUND** while writing an adopter pattern-tour
example: struct-destructure with a guard always takes the first
arm's body, regardless of whether the guard evaluates true.

**Repro (minimal):**

```nr
struct Point { x: i32, y: i32 }

fn check(p: Point) -> i32 {
    match p {
        Point { x, y } if x == 0 => 100,
        Point { x, y } => x + y,
    }
}

fn main() -> i32 {
    print_int(check(Point { x: 3, y: 4 }));   // expected 7  → ACTUAL: 100
    print_int(check(Point { x: 0, y: 99 }));  // expected 100 → 100 (correct by accident)
    0
}
```

`x: 3, y: 4` should fall through the first arm (guard `x == 0`
is false) and match the second arm, returning `x + y = 7`. Instead
it executes the first arm's body and returns 100.

**Suspected:** the codegen for a struct-destructure pattern arm
emits the body BEFORE the guard check, OR doesn't emit the
guard-failure branch correctly. Plain integer pattern guards work
fine (verified: `match x { n if n > 100 => 1, n => n }` falls
through correctly when the guard fails).

**Discovered against:** v0.4.200.

**Severity:** silent-miscompute. Adopter writing the v0.5+
field-equality workaround pattern (`Point { x, y } if x == 0 && y == 0`)
gets WRONG results for non-origin Points.

**Cross-ref:** RFC-0023 audit (v0.4.171) — pattern guards on
SIMPLE patterns work; the bug surfaces only with struct
destructure as the pattern shape.

**Workaround for adopters today:** explicit field comparison
without struct destructure binding the same names:

```nr
fn check(p: Point) -> i32 {
    let x: i32 = p.x;
    let y: i32 = p.y;
    if x == 0 { return 100; };
    x + y
}
```

Probe agent: please isolate the codegen path (likely match-arm
lowering at kind-49 or kind-39 with guard branching on struct
patterns) and file the formal finding.
