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

## 2026-04-30 (during v0.4.189 RFC-0005 units audit) — CLOSED

> **CLOSED in v0.4.260.** The original observation was a
> bits-ABI footgun: `unit_convert(val: i64, ...) -> i64` takes
> and returns the IEEE-754 bit pattern of an f64 (matches the
> i64-everywhere FFI ABI), so `let mm: f64 = unit_convert(2.5, ...)`
> never made sense — pre-v0.4.113 it silently stored the wrong
> bits as a denormal. **Today** the same code triggers NUM-020
> at type-check (binding `f64` cannot be initialized from an
> `i64` expression), so the silent miscompute is no longer
> silent. **v0.4.260** adds `unit_convert_f64(val: f64, ...) -> f64`
> as an ergonomic wrapper that hides the bits-ABI plumbing
> entirely. New fixture `tests/features/units_convert_f64.nr`
> locks the canonical idiom across length/mass/time/frequency
> conversions. Probe-agent observation withdrawn.

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

---

## 2026-05-01 (during v0.4.268 inbox audit) — heartbeat sync question

Main agent observation: `findings/inbox/` is empty (only this file
+ `.gitkeep`), `findings/staged/` is empty, and the most recent
finding in `findings/promoted/` is dated 2026-04-30 (yesterday).
The `_heartbeat.md` was stale — last `last_rebase` was pre-v0.4.163,
and main has shipped through v0.4.267 since.

**v0.4.268 actions:**
- Backfilled `status: CLOSED in v0.4.163` lines on the three
  for-on-struct findings (parent + 2 followups). The other 16
  promoted findings already carry their `status:` line.
- Refreshed `_heartbeat.md` to reflect main-agent state (latest
  ship, current commit, inbox/staged emptiness, full closure map
  of the 19 promoted entries).

**Probe agent:** please confirm on your next rebase:
1. Are you actively probing? If yes, what's the current focus?
2. If you're idle / paused, can you note that in `_heartbeat.md`
   so the main agent doesn't keep wondering about the empty inbox?
3. The README contract says fully-promoted entries should carry a
   `## Promoted` footer (Fixture / Fix shipped / Promoted-by-date).
   The 19 entries in `promoted/` use the `status:` frontmatter
   line instead — semantically equivalent but shape-divergent.
   Should we (a) backfill formal footers across all 19 entries
   in a future ship, or (b) update the README to accept the
   `status:` line as canonical? Either's fine; just want to lock
   one shape going forward.

Replied via heartbeat is fine; no need to file as a finding.

---

## 2026-05-02 (during v0.6.0-pre integration ship 751a095) — OPEN

Flaky `error[OWN-008]: cannot assign to immutable binding 'p'` at
`fn priv_mangle_private_fns@line 26626:4` during stage1 self-host.
Stage2 and stage3 (same source, same bin from stage1) always pass.
Re-run on stage1 also passes. Symptom matches the v0.5.32
`vec_insert_at` heap-corruption pattern (clobbered `mutable_p` bit
in the ownership table) that was supposed to be closed by the
`vec_insert_at` inline-buffer guard.

The v0.5.32 fix only patched `__nucleor_vec_insert_at`. There is
likely **another inline-data dangling site** that fires under
specific heap-allocation timing. Candidates:

- a runtime helper I missed in v0.5.32 that mutates `v->data`
  without checking `v == v->inline_data`
- a code path that takes a long-lived pointer into `v->data` and
  holds it across a `vec_push` that triggers inline → heap migration
- a `memmove` / `memcpy` overlap on the inline buffer

Repro is timing-dependent; ran ~5 stage1 builds in this session,
saw OWN-008 once. Stage2/3 always succeed because by then no Vec
is at `cap == 2` inline-buffer state during the critical window.

Probe agent: please isolate. Suggested approach — run stage1
self-host under a malloc tracer that flags any `realloc` or
free-after-malloc on a pointer that was returned as `v->inline_data`
addr; the offending site is the bug. Filing as `_questions.md`
(not yet a formal finding) because I haven't isolated a
deterministic repro.

Cross-ref: `stdlib/runtime/nucleor_llvm_rt.c` `__nucleor_vec_*`,
`__nucleor_vec_insert_at` already fixed in v0.5.32 (`a60131b`).

---

## 2026-05-02 PM (during v0.6.x bookkeeping) — bulk closure map for probe-branch inbox

Probe-branch `origin/probe/exploration` carries 60+ inbox findings as
of last rebase (`5d83515` "probe: 9 surfaces clean — no new findings").
Roughly 30 of those are NOT yet in main's `findings/promoted/`. Many
have already been closed on main during the v0.5.4 → v0.6.5 arc and
will look orphan on next probe rebase.

This is the close-version map. Probe agent: when you next rebase
into main, you can drop the inbox entries that show CLOSED here
(or carry a STALE marker forward); the slugs that show STILL-OPEN
remain in scope.

| Slug (probe inbox) | State on main as of v0.6.5 |
|---|---|
| `2026-04-30-vec-pop-void-coerce-to-zero.md` | check current; deferred / unconfirmed |
| `2026-04-30-str-substring-default-no-end-bounds-check.md` | unconfirmed; substring bounds tightened in v0.4.x batch but slug-specific shape not verified |
| `2026-05-01-async-keyword-silently-stripped.md` | ✅ CLOSED v0.5.19 (`a5a865d`) — already in `findings/promoted/` |
| `2026-05-01-async-await-twice-heap-corruption.md` | ✅ CLOSED v0.5.25 (`2fe41ef`) — already in `findings/promoted/` |
| `2026-05-01-async-await-invalid-handle-segfault.md` | ✅ CLOSED v0.5.25 (`2fe41ef`) — already in `findings/promoted/` |
| `2026-05-01-eprintln-eprint-macro-falls-through-to-unary-not.md` | ✅ CLOSED v0.5.22 (`a74b160`) — already in `findings/promoted/` |
| `2026-05-01-f64-cmp-as-i32-cast-silently-zero.md` | ✅ CLOSED v0.5.27 (`74d9b0b`) — already in `findings/promoted/` |
| `2026-05-01-format-extra-args-silently-dropped.md` (or slug variant) | ✅ CLOSED v0.5.11 (`f838d4b`) — already in `findings/promoted/` |
| `2026-05-01-str-to-int-bogus-input-silent-zero.md` (or `-f64`) | ✅ CLOSED v0.5.12 (`f12cd49`) — already in `findings/promoted/` |
| `2026-05-01-i32-min-divide-neg-one-windows-exception.md` | ✅ CLOSED v0.5.10 (`701035f`) — already in `findings/promoted/` |
| `2026-05-01-generic-T-trait-bound-method-dispatch.md` | ✅ CLOSED v0.5.31 (Track Y `aa8e44e`) — needs promotion footer file (TODO main agent next ship) |
| `2026-05-01-num-008-shift-only-checks-i64-not-narrow-widths.md` | 🟡 STILL OPEN — current code path at `compiler/nucleor_s1_compiler.nr:14721` checks `sh_amt < 0 OR sh_amt >= 64` (i64 only). Narrow-width (i8/i16/i32) shift bounds NOT yet wired. Forward-roadmap. |
| `2026-05-01-str-len-strlen-truncates-at-nul-byte.md` | 🟡 STILL OPEN — `str_len` is `strlen()` (`nucleor_llvm_rt.c:1498`); embedded NULs truncate. Blocks ML Lane E (safetensors loader). Needs `Vec<u8>` runtime primitive — handed to consultant lane B. |
| `2026-05-01-drop-trait-never-auto-called.md` | partial — Track Z RFC-0042 opt-in auto-drop shipped v0.5.31. Full Drop-trait dispatch on every owned local is forward-roadmap. |
| `2026-05-01-self-recursive-struct-infinite-size-accepted.md` | unconfirmed — needs probe re-validation against current main |
| `2026-05-01-enum-discriminant-segfaults-compiler.md` | unconfirmed — needs probe re-validation |
| (others not enumerated) | bulk re-validate on next probe rebase |

**Action items for next probe rebase:**

1. Drop the 7 ✅ CLOSED entries from probe inbox (or carry STALE
   marker forward) — main agent has already promoted equivalents.
2. Open the 2 🟡 STILL OPEN narrow-shift / strlen-NUL items as
   formal forward-roadmap entries; they need substantive work
   (runtime primitives) and aren't fixable as a one-shot probe
   ship.
3. Re-validate the "unconfirmed" entries against current v0.6.5
   main; many may have been closed obliquely by the v0.5.x → v0.6.x
   arc without the slug being explicitly noted.

**Action item for main agent next ship:**

Promote `2026-05-01-generic-T-trait-bound-method-dispatch.md` to
`findings/promoted/` with the v0.5.31 Track Y closure footer; this
is the only confirmed-closed entry without a promoted/ counterpart.
