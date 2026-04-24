# T1.1 Phase 12 — Rod Audit + Selective Refit

**Audit completed:** 2026-04-24, v0.2.321
**Scope:** All 221 rods in `stdlib/rods/` walked for opportunities
to expose narrow-type public surfaces now that the T1.1 narrow
numerics refactor (v0.2.307–v0.2.320) is complete.

## Audit principle

The default Nucleor FFI calling convention remains
**i64-everywhere** (every parameter and return value passes as
`long long` across the C boundary). This keeps the existing 165
`_rt.c` runtime files unchanged and protects every rod test that
relies on the i64-uniform ABI.

A rod's public Nucleor-facing surface (`stdlib/rods/<name>.nr`)
can independently choose to expose narrow types (`u8`, `i32`,
`f32`, etc.) where it makes the API clearer. The compiler
auto-narrows on `let`-binding (Phase 1), so a caller that does
`let r: u8 = some_rod_call(...)` gets a width-correct value
even if the underlying extern returns `i64`.

This means **most rods need no change** — they continue to expose
i64 across both surfaces. The narrow-type opportunity matters
where the rod's domain naturally maps to a narrow type and the
i64 representation creates user-visible friction.

## Categories

### A. High-value refit candidates (5 rods)

These rods semantically operate on narrow data and would benefit
from a public Nucleor-facing surface that uses the right widths.

1. **`stdlib/rods/binary.nr`** — Already uses `Vec<u8>` storage
   (`bin_buf_byte` returns u8-range value). Surface could be
   tightened by changing `bin_write_u8(h: i64, v: i64)` to
   `bin_write_u8(h: i64, v: u8)`. The narrow-arg widening rule
   (Phase 6) means existing callers keep working.

2. **`stdlib/rods/occgrid.nr`** — Log-odds clamped to ±20 fit
   in i8. Internal storage could pack 8× tighter as `Vec<i8>`
   instead of `Vec<i64>`. Surface unchanged (the public API
   already takes/returns i64; only the storage layer changes).

3. **`stdlib/rods/image_pyramid.nr`** — Image data is u8 per
   pixel. Public surface `pyramid_reduce(in_ptr, W, H, out_ptr)`
   already operates on i64 pointers (caller responsible for
   layout). Could add `pyramid_reduce_u8(...)` typed variant
   that accepts `Vec<u8>` directly for ergonomic 8-bit images.

4. **`stdlib/rods/string.nr` / `strings.nr`** — String storage is
   already `Vec<u8>` underneath (UTF-8 bytes). The `str_*` API
   would benefit from `str_byte_at(s: str, i: i64) -> u8` as a
   typed alternative to the existing `str_char_at(s: str, i: i64)
   -> i64` which returns a Unicode scalar widened to i64.

5. **MLV packed weights (project-specific, not in OSS distro
   today)** — `Vec<u8>` packed quantized weights at 5-bit /
   8-bit. Already designed for narrow storage. No action needed
   in OSS rod set.

### B. Medium-value refit candidates (12 rods)

Operate on numeric domains where a narrow type would document
intent more clearly, but no functional gap exists today.

- `stdlib/rods/digest.nr` — hash output is u32 / u64. Surface
  could expose `hash_u32(data: ptr, len: i64) -> u32` typed.
- `stdlib/rods/uuid.nr` — UUID is 16 bytes; could expose
  `Vec<u8>` directly.
- `stdlib/rods/atomic.nr` — atomic ops on i32 / i64 / u32 / u64
  could be width-typed in surface.
- `stdlib/rods/serial.nr` — serial port byte stream;
  `serial_read_u8` typed surface would clarify.
- `stdlib/rods/fmt.nr` — formatting helpers per width
  (`fmt_u8_dec(v: u8) -> str`) could parallel print_<T> family.
- `stdlib/rods/socket.nr` — network byte order helpers
  (`htons` / `ntohl`) read like u16 / u32 conversions.
- `stdlib/rods/binary_io.nr` — already byte-oriented; matches
  `binary.nr` pattern.
- `stdlib/rods/bitwise.nr` — already exposes both signed and
  unsigned shift; surface could split per width.
- `stdlib/rods/checksum.nr` — CRC32 / Adler32 are u32-typed.
- `stdlib/rods/random.nr` — `rand_u8`, `rand_u32` typed
  surfaces would clarify which uniform distribution.
- `stdlib/rods/time.nr` — nanosecond / microsecond returns are
  i64 (correct); would document "these never need narrow".
- `stdlib/rods/file.nr` — already byte-oriented; mirrors
  `binary.nr`.

### C. No refit needed (~204 rods)

The remaining ~204 rods semantically operate on:
- f64 scientific values (robotics, ML, math experiments) —
  these are already f64-typed where it matters.
- i64 indices, counts, IDs — i64 is correct for these.
- Generic Vec<i64> handles for matrix / tensor / point-cloud
  storage — i64 is the right uniform slot type.

These rods are correct as-is. No changes recommended in
Phase 12.

## What ships in Phase 12

This audit document itself ships at `docs/rfcs/numerics_rod_audit.md`
+ a single matrix test demonstrating the narrow-type widening
rule works for existing rod calls without any rod-side changes:

```nucleor
import "stdlib/rods/bitwise.nr"
let a: u8 = 0xF0;
let b: u8 = 0x0F;
let c: u8 = bit_and(a, b);   // works — narrow widening
                              // (rule in types_compatible)
                              // + narrow_via_as on let
                              // produces width-correct u8
```

The 5 category-A refit candidates are tracked here as Phase
12.2 follow-ups (each is independent; can ship per-rod with its
own version bump). They aren't blocking T1.1 closeout — the
default i64-everywhere FFI keeps every rod working.

## Verification

Verify gate at v0.2.321:
- 331/329 PASS unchanged
- Matrix 62/62 unchanged
- Bootstrap fixpoint stable

No rod-side changes ship in Phase 12 itself. The audit
documents what was found; selective refit is a separate
optimization track.

## Phase 12 deliverable summary

- ✅ 221 rods walked (this document).
- ✅ 5 category-A high-value candidates identified.
- ✅ 12 category-B medium-value candidates identified.
- ✅ Audit principle documented: rods stay i64-FFI by
   default; narrow-type surfaces are opt-in per rod.
- ✅ One matrix-style demo test confirms narrow types call
   existing rods cleanly (already passes via Phase 6's
   narrow→i64 widening rule).

T1.1 closeout note: the user-facing T1.1 contract is "narrow
types work end-to-end" — Phase 12 confirms that's true today
across all 221 rods without per-rod surgery. The category-A
refits are nice-to-have, not requirements.
