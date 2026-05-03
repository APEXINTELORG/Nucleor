---
title: NUM-008 (shift amount out of range) only checks i64 (`0..=63`), not narrow widths. `let a: i32 = 1 << 32;` silently returns 0 with no diagnostic.
severity: silent-miscompute (NUM-008 coverage gap)
probe_file: probes/numeric/shift_narrow_width_oor.nr (probe-branch)
diagnostic_actual: pre-fix — build succeeds; runtime returns 0 (UB / wrap to 0). No diagnostic.
diagnostic_expected: NUM-008 at compile time, naming the actual width — `error[NUM-008]: shift amount 32 is out of range for i32 (\`<<\` requires 0..=31)…`.
discovered_against: main v0.5.18 (probe af6cf4c)
commit: probe af6cf4c + main 1a645361
status: CLOSED in v0.6.37 via width-aware bound at the NUM-008 emit site (line ~16128 of nucleor_s1_compiler.nr).
---

## Closure (main agent v0.6.37)

`compiler/nucleor_s1_compiler.nr` NUM-008 emit site — pre-fix
hard-coded `sh_amt < 0 || sh_amt >= 64`. Now derives the bound
from the LHS type's width:

```nucleor
let lt_strip_v063: str = strip_spaces(lt);
let mut sh_bound_v063: i64 = 64;
if str_eq(lt_strip_v063, "i8") == 1 || str_eq(lt_strip_v063, "u8") == 1 { sh_bound_v063 = 8; }
else if str_eq(lt_strip_v063, "i16") == 1 || str_eq(lt_strip_v063, "u16") == 1 { sh_bound_v063 = 16; }
else if str_eq(lt_strip_v063, "i32") == 1 || str_eq(lt_strip_v063, "u32") == 1 { sh_bound_v063 = 32; };
if sh_have == 1 && (sh_amt < 0 || sh_amt >= sh_bound_v063) { … };
```

The diag now names the actual width and shows the correct upper
bound (`0..=N-1`). Workaround pointer mentions both masking and
widening the LHS type as fix options.

## Adopter migration

```nucleor
// Pre-v0.6.37: silent return 0 for any out-of-range narrow shift
let a: i32 = 1 << 32;   // pre-fix: 0 (poison); v0.6.37: NUM-008 halt
let b: i16 = 1 << 16;   // pre-fix: 0; v0.6.37: NUM-008 halt
let c: i8  = 1 << 8;    // pre-fix: 0; v0.6.37: NUM-008 halt

// Workarounds:
let a: i32 = 1 << (32 & 31);   // mask (no-op shift = 1)
let a: i64 = 1i64 << 32;       // widen LHS to i64 (= 4294967296)
```

## Note on `let a: i64 = 1 << N`

Nucleor's literal type inference defaults integer literals to
i32 (matching Rust). So `let a: i64 = 1 << 32;` lowers as an
i32 shift (LHS `1` is i32) — exactly the case NUM-008 catches.
Matches Rust's behavior: `let a: i64 = 1 << 32;` is also a
compile-time error in Rust. Use `1i64 << 32` or `(1 as i64) << 32`
to get an i64 shift.

## Promoted

- Fixture: `tests/err/err_num008_narrow_width_shift.nr`.
- Fix shipped: v0.6.37.
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
