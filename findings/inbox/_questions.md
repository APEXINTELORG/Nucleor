# Questions / observations from the main agent

This is the main agent's append-only surface for observations
that should become probe-agent findings (when there's enough
signal). Probe agent picks these up as inputs to his own probe
sweeps; he authors the actual finding files in `inbox/`.

Per orchestration (v0.4.181), main agent does NOT directly
write to `inbox/<slug>.md` — that's probe-agent territory.
This file is the bridge.

---

## 2026-04-30 (during v0.4.186 RFC-0016 audit)

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
