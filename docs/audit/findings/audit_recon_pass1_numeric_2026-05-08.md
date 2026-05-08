# RECON Pass-1 Audit — Numeric / SI Units / Overflow (Layer 8)

**Date:** 2026-05-08
**Scope:** Integer overflow / underflow rules, float NaN/inf/subnormal handling, float ↔ int conversions, mixed-precision arithmetic, SI unit dimensional analysis (RFC-0005), numeric type promotions / coercions, bit operations on signed vs unsigned, numeric literal type inference (RFC-0015).
**Binary:** `bin/nucleor.exe` v1.0 (path: `Nucleor_OSS_integrate_r05_with_row_v0842`)
**Methodology:** Source-level review of `compiler/nucleor_s1_compiler.nr`, `stdlib/rods/numeric*`, `stdlib/rods/units*`, `stdlib/runtime/units_rt.c`, `stdlib/runtime/numeric_rt.c`, `stdlib/runtime/nucleor_llvm_rt.c`, plus 36 minimal compile-and-run probes in `audit_scratch_numeric/`. Differential checks executed against system Python (CPython) using `struct.pack`/`struct.unpack` for bit-exact f64 verification. NO source modifications. NO verify.sh.
**Out of scope:** stdlib math functions (Layer 9a), codegen optimizer numerical semantics (Layer 6 — but cross-layer notes appear below where the optimizer overlaps).

## Inventory

| Component | File | Notes |
|---|---|---|
| Numeric primitives RFC | `docs/rfcs/RFC-0015-numeric-types.md` | "Implemented (partial) v0.1.46-v0.1.64; strict-mode deferred to v0.4" |
| Cast matrix RFC | `docs/rfcs/numerics_cast.md` | Documents the implementation dispatch table |
| SI units RFC | `docs/rfcs/RFC-0005-units.md` | "Partial (audited v0.4.189) — UNIT-001..005 emit sites are not yet wired into the type checker. Deferred to v0.6+" |
| 7-vector typed-units RFC | `docs/rfcs/RFC-0047-typed-units-7vector.md` | Phase A only — runtime Vec<i64> dim helpers, no type-checker enforcement |
| Numeric rod | `stdlib/rods/numeric.nr` (112 lines) | wrapping_/saturating_/checked_, narrow truncation casts, FMA, rounding modes |
| Numeric runtime | `stdlib/rods/numeric_rt.c` (83 lines) | fma, fegetround/fesetround, nextafter |
| Units rod | `stdlib/rods/units.nr` (479 lines) | Unit IDs, unit_convert_f64, dim_*() vectors, UnitDistance/Velocity/Time/Mass/Acceleration structs |
| Units runtime | `stdlib/runtime/units_rt.c` (180 lines) | to_si / from_si pivot conversion via SI baseline |
| Bitwise rod | `stdlib/rods/bitwise.nr` + `bitwise_rt.c` | bit_and/or/xor/not, shift_left, shift_right (logical), shift_right_signed, bit_test/set/clear |
| Numeric runtime cast helpers | `stdlib/runtime/nucleor_llvm_rt.c` lines 5217-7968 | `__nucleor_f64_to_{i32,i64,u32,u64}`, `__nucleor_f32_to_{i32,u32,i64,u64}`, etc. |

Notable absences:
- No `f64_to_{i8,u8,i16,u16}` runtime helpers exist anywhere in the tree (verified by grep across the whole project). All such casts fall through the integer-bit-cast path.
- RFC-0005 promised `unit<T, dim>` compile-time dimension algebra is **not** implemented — there is no parser/type-checker enforcement; only nominal struct surface in `units.nr`.
- The `unit_convert` runtime FFI pivot (units_rt.c) is purely numeric — it has no awareness of dimension category.

---

## Findings

### F-NUM-001 — `f64 as u8 / i8 / u16 / i16` returns the low byte(s) of the f64 BIT PATTERN, not the numeric value  [CRITICAL]

**Location:** `compiler/nucleor_s1_compiler.nr` cast-lowering (kind == 99 in `lower_expr`); `docs/rfcs/numerics_cast.md` §"Implementation"; lack of `__nucleor_f64_to_{i8,u8,i16,u16}` helpers in `stdlib/runtime/nucleor_llvm_rt.c`.

**Evidence (probe `t33_f64_narrow_matrix.nr`):**
```nucleor
let v: f64 = 50.0;
print(str_concat("f64(50)->i8 ",  str_from_int((v as i8)  as i64)));   // 0
print(str_concat("f64(50)->u8 ",  str_from_int((v as u8)  as i64)));   // 0
print(str_concat("f64(50)->i16 ", str_from_int((v as i16) as i64)));   // 0
print(str_concat("f64(50)->u16 ", str_from_int((v as u16) as i64)));   // 0
print(str_concat("f64(50)->i32 ", str_from_int((v as i32) as i64)));   // 50
print(str_concat("f64(50)->u32 ", str_from_int((v as u32) as i64)));   // 50
print(str_concat("f64(50)->i64 ", str_from_int(v as i64)));            // 50
```
The IR (`target/t30_f64_to_narrow.ll`) shows `r.4 = call i64 @__nucleor_as_u8(i64 %r.1)` where `r.1` is the f64 bit pattern (`4756540486875873280` for `1e10`). `__nucleor_as_u8` masks low 8 bits — for any "round" f64 (mantissa low bits zero) this returns 0.

`docs/rfcs/numerics_cast.md` "Implementation" dispatch table only enumerates the four pairs `f32→i32, f32→u32, f64→i32, f64→u32` plus `(any) → i64` bit-preserve and `(int) → (int)` mask. f64→i8/u8/i16/u16 is not in the table — the implementation defers to the integer-mask path on the bit pattern.

**Why it matters:**
- RFC-0015 §3.5 explicitly promises "Float → integer: Round toward zero, saturate at limits" for **all** float-to-integer casts.
- Image processing, color conversion, audio sample quantization, and ML quantization (bf16/f16/f8 lowered to f32 then to u8 for storage) all hit this path. Every value silently becomes 0 or junk, with no diagnostic.
- This is silent, not a panic, not a warning.

**Severity:** Critical (silent miscompute on a documented language feature).

**Remediation:**
1. Add runtime helpers `__nucleor_f64_to_{i8,u8,i16,u16}` and `__nucleor_f32_to_{i8,u8,i16,u16}` matching the existing pattern in `nucleor_llvm_rt.c` (saturate at the narrow-int range, NaN→0, then truncate).
2. Extend the cast dispatch table in `compiler/nucleor_s1_compiler.nr` (search "kind == 99") to route `f64→{i8,u8,i16,u16}` and `f32→{i8,u8,i16,u16}` to the new helpers instead of falling through to `as_<T>`.
3. Update `docs/rfcs/numerics_cast.md` dispatch table to enumerate the eight new pairs.
4. Add regression tests in `tests/lang/numerics_matrix/p4_cast/` for each of the eight new pairs at boundary points (negative, zero, +inf, -inf, NaN, ±boundary, mid-range).

---

### F-NUM-002 — `unit_convert_f64` accepts cross-dimensional conversions silently (Pa→m, J→Hz, V→s, kWh→deg)  [CRITICAL]

**Location:** `stdlib/runtime/units_rt.c` lines 60-163 (`to_si`, `from_si`, `nuc_unit_convert`).

**Evidence (probe `t20_si_cross_dim.nr`):**
```nucleor
print(f64_to_str(f64_to_bits(unit_convert_f64(100.0, unit_Pa(), unit_m()))));   // 100
print(f64_to_str(f64_to_bits(unit_convert_f64(1.0,   unit_J(),  unit_Hz()))));  // 1
print(f64_to_str(f64_to_bits(unit_convert_f64(1.0,   unit_kWh(),unit_deg())))); // 2.06265e+08
print(f64_to_str(f64_to_bits(unit_convert_f64(1.0,   unit_V(),  unit_s()))));   // 1
```
`to_si(100.0, U_PA)` returns `100.0` (Pa is the SI baseline for pressure); `from_si(100.0, U_M)` returns `100.0` (m is the SI baseline for length). The two switch statements share a single anonymous `double si` slot — there is no record of what dimension category `si` belongs to, so any pair of categories that happen to share an SI scaling of `1.0` round-trips with no error.

The kWh→deg case is even more misleading: `to_si(1.0, U_KWH) = 3_600_000` (joules); `from_si(3_600_000, U_DEG) = 3_600_000 * 180 / π ≈ 2.063e8`. The user gets a plausible-looking number with no warning.

**Why it matters:**
RFC-0005 §1 states the explicit motivation: "Catches the Mars Climate Orbiter bug class at compile time." `unit_convert_f64` is the only unit-conversion primitive shipping in v1.0 and it admits the exact bug class the RFC was created to prevent. Robotics, control, and aerospace adopters using the rod-level surface (the only one available — typed `unit<T, dim>` is deferred to v0.6+) get zero protection.

`stdlib/rods/units.nr` lines 109-185 ship `dim_eq` / `dim_check_or_panic` / `dim_*()` 7-vector helpers, but `unit_convert_f64` itself does not call them. `dim_check_or_panic` exists and even documents the failure-mode message; it just is not wired into the conversion path.

**Severity:** Critical (silent miscompute; the central RFC-0005 motivation is unfulfilled).

**Remediation:**
1. In `units_rt.c`, partition the unit ID space into category tags (length, mass, time, current, temperature, pressure, energy, force, frequency, angle, voltage). Today the IDs follow a 10-stride convention (1-7, 10-13, 20-25, 30-32, 40-44, 50-54, 60-62, 70-73, 80-81, 90-93) — derive the category by `id / 10` (with a guard for the IDs ≤ 9).
2. In `nuc_unit_convert`, fail when `category(from) != category(to)`. Two options:
   - Return a sentinel f64 (NaN with a diagnostic-encoded mantissa) and have the rod wrapper `unit_convert_f64` check + panic with a clear message.
   - Add a return-status int and refactor the FFI to `nuc_unit_convert(val, from, to, *out)`.
   The first option preserves the i64-everywhere FFI shape; the second is cleaner but breaks the ABI.
3. Reserve / wire UNIT-001 (the RFC-0005 diagnostic code) to fire from the rod at the call site. This is a runtime check, not the compile-time check the RFC promised, but it is a stop-gap until v0.6 lands the typed surface.
4. Add a positive test matrix at `tests/lang/units_*` covering every (category, category) pair: same-category should pass, cross-category should panic with UNIT-001-style message.

---

### F-NUM-003 — `bit_shift_left`, `bit_shift_right`, `bit_set`, `bit_clear`, `bit_test` invoke C undefined behaviour for shift counts ≥ 64 or < 0  [CRITICAL]

**Location:** `stdlib/rods/bitwise_rt.c` lines 20-44.

**Evidence (probe `t14_shift_ub.nr`):**
```nucleor
print(str_concat("1 << 64 = ", str_from_int(bit_shift_left(1, 64))));   // 1
print(str_concat("1 << 65 = ", str_from_int(bit_shift_left(1, 65))));   // 2
print(str_concat("1 << -1 = ", str_from_int(bit_shift_left(1, 0 - 1)))); // -9223372036854775808
print(str_concat("bit_set(0,64) = ", str_from_int(bit_set(0, 64))));     // 1
```
C runtime is `return a << n;` with no bounds check on `n`. The C standard (§6.5.7p3) says "If the value of the right operand is negative or is greater than or equal to the width of the promoted left operand, the behavior is undefined." On x86, the SHL instruction masks the count to the low 6 bits for 64-bit operands — hence `1 << 64 ≡ 1 << 0 = 1`, `1 << 65 ≡ 1 << 1 = 2`, `1 << -1 ≡ 1 << 63 = i64::MIN`.

`rods_bit_set(val, 64)` runs `1LL << 64` → 1, then ORs into val. `rods_bit_test(val, 65)` reads bit 1 instead of bit 65. `rods_bit_shift_right(a, 64)` is also UB.

**Why it matters:**
- Crypto rods (`stdlib/rods/crypto.nr`, `digest.nr`) and any user code hashing/serializing data uses these helpers. A 64-bit mask construction `bit_set(0, n)` for user-supplied `n` produces wrong values for `n ≥ 64` instead of failing.
- Compiler optimizer may fold `1 << 64` to `0` at compile time and call site to `1` at runtime — divergence between constant-folded and runtime arithmetic is classically how UB sneaks into security bugs.

**Severity:** Critical (UB is the spec).

**Remediation:**
1. Bounds-check shift count in each runtime function: `if (n < 0 || n >= 64) return 0;` (logical / unsigned) or `return a < 0 ? -1 : 0;` (signed arithmetic shift). Match the chosen rule in the rod doc-comment.
2. Alternatively, panic on out-of-range count (consistent with int division-by-zero policy in v1.0).
3. Document the chosen policy in the rod header comment and in `RFC-0015-numeric-types.md` §3.3 (overflow modes — shifts are not "overflow" per se but should be in the same section).
4. Add regression tests: `bit_shift_left(1, 0..=63)` covers the valid range; `bit_shift_left(1, 64)`, `bit_shift_left(1, -1)`, `bit_shift_left(1, 1000)` should each have a defined behaviour (panic or 0) per the chosen policy.

---

### F-NUM-004 — RFC-0015 §3.2 mixed-width arithmetic (no implicit conversion) is not enforced  [HIGH]

**Location:** Type-checker in `compiler/nucleor_s1_compiler.nr`. RFC-0015 itself acknowledges "strict-mode deferred to v0.4" — but this is **the** v1.0 release and the deferral has not closed.

**Evidence (probe `t15_mixed_prec.nr`):**
```nucleor
let a: i32 = 100;
let b: u32 = 200;
let c: i32 = a + (b as i32);   // explicit cast
let d: i32 = a + b;            // RFC-0015 §3.2: should be NUM-001
print(str_from_int(c as i64));
print(str_from_int(d as i64));
```
Both lines compile and produce `300`. NUM-001 ("Mixed-width arithmetic without cast") never fires.

**Why it matters:**
- The whole RFC-0015 safety story ("Decision: model on Rust. Distinct, no implicit conversion, explicit `as` cast") is what differentiates Nucleor's numeric types from Go-style implicit promotion. Shipping v1.0 without enforcement removes that differentiator silently.
- Adopters writing `i32 + u32` today get a friendly but wrong answer; when v0.4-strict-mode finally lands, every existing program breaks.

**Severity:** High (documented language guarantee not held).

**Remediation:**
1. Either (a) ship NUM-001 enforcement now (preferred — it is what every rod test already assumes), or (b) explicitly amend RFC-0015 §3.2 to mark "implicit numeric conversion is permitted in v1.0; strict mode is opt-in via a future profile flag" and update the v1.0 CHANGELOG to document the divergence from the RFC.
2. If (a): add the type-checker rule in the binop type-resolution path; emit NUM-001 with a `help: cast with `as` to match types` annotation. The diagnostics file already has slot UNIT-001..005 reserved; NUM-001..005 needs the same treatment.
3. Run `nuc fix --numeric` (which the RFC promises ships) over the full stdlib + tests to close any rod that depends on implicit conversion before flipping the rule on.

---

### F-NUM-005 — `as` cast precision-loss diagnostic NUM-003 is not emitted  [MEDIUM]

**Location:** Cast-lowering and warning subsystem in `compiler/nucleor_s1_compiler.nr`.

**Evidence (probe `t21_lossy_cast.nr`):**
```nucleor
let big: i64 = 1000;
let s: i8 = big as i8;     // 1000 -> i8 silently produces -24 (1000 mod 256 - 256)
print(str_from_int(s as i64));   // -24

let big_int: i64 = 9007199254740993;   // 2^53+1, not representable in f64
let as_f: f64 = big_int as f64;
// silently rounds to 9007199254740992
```
Compile produces no warning. Runtime prints `-24` and `9.0072e+15`.

**Why it matters:**
RFC-0015 §3.9 explicitly enumerates `NUM-003 — `as` cast loses precision (warning)`. Adopters who ship `let pixel: u8 = intensity as u8` expecting RFC-0015 NUM-003 to flag values that may saturate get no warning at all. Combined with F-NUM-001 (where the cast also silently produces 0 for narrow targets), this creates a perfect storm.

**Severity:** Medium (documented warning not emitted).

**Remediation:**
1. Wire NUM-003 in cast-lowering: emit the warning when the source type strictly contains values outside the destination type's range and the source is not a literal proven in-range by const-eval.
2. Distinguish the f64→f32 case (always lossy for >24-bit mantissa) from the i64→i32 case (lossy only when source dynamic range exceeds dest). The existing const-tracker already proves runtime-known bounds for many cases — re-use it.
3. Provide `#[allow(precision_loss)]` (or `#[allow(NUM-003)]`) on the call site to suppress where intentional, per the RFC §3.9.

---

### F-NUM-006 — Imperial unit conversion constants are truncated, introducing 10⁻⁹ relative error  [MEDIUM]

**Location:** `stdlib/runtime/units_rt.c` lines 60-105 and 109-156.

**Evidence:**
| Unit | Constant in code | Spec value | Δ |
|---|---|---|---|
| `U_OZ` | `0.028349523` | `0.028349523125` (1 oz / 16 lb · 0.45359237) | 1.25e-10 absolute |
| `U_PSI` | `6894.757` | `6894.757293168361` (1 psi = 6894.757... Pa) | 2.93e-4 relative |
| `U_LBF` | `4.448222` | `4.4482216152605` (defn) | 3.85e-7 relative |

For example, `unit_convert_f64(100.0, unit_psi(), unit_Pa())` returns `689475.7` instead of `689475.7293...`. Round-trip oz→kg→oz returns `1.000000044` instead of exactly `1`.

**Why it matters:**
- For instrumentation, control loops at the cm/Pa/N level the error is invisible.
- For high-precision metrology, calibration, or compliance with international standards (NIST, BIPM) the constants advertise 7 digits but ship 4-7. A library that promises SI conversion should carry conversion factors at the f64 limit (15-16 sig figs).

**Severity:** Medium (silent precision loss; gates use of v1.0 in scientific computing).

**Remediation:**
1. Replace literal constants with full-precision values:
   - `U_OZ`: `0.028349523125`
   - `U_PSI`: `6894.7572931683604`
   - `U_LBF`: `4.4482216152605`
   - Verify every other constant in the table; `U_FT` (0.3048), `U_IN` (0.0254), `U_MI` (1609.344), `U_LB` (0.45359237), `U_CAL` (4.184), `U_EV` (1.602176634e-19) are exact by definition; cross-check the rest.
2. Add a regression test: round-trip every imperial→SI→imperial pair and assert ≤ 1 ulp drift over `[1e-3, 1e6]` magnitude range.

---

### F-NUM-007 — `nuc_unit_si_prefix` leaks heap memory and never frees the formatted buffer  [MEDIUM]

**Location:** `stdlib/runtime/units_rt.c` lines 165-179.

**Evidence:**
```c
char *buf = (char *)malloc(64);
snprintf(buf, 64, "%.3f %s%s", val / scales[best], prefixes[best], unit ? unit : "");
return buf;
```
The function allocates 64 bytes per call and returns the pointer to the caller. There is no companion `nuc_unit_si_prefix_free` and no caller-owns convention documented. Any rod calling this in a loop (e.g. logging telemetry) leaks 64 B per invocation.

**Why it matters:**
- For long-running embedded or robotics programs (RFC-0005 §6 explicitly cites "robotics weekly"), this leak is unbounded.
- The lack of NaN/inf/zero special-casing in the prefix loop means `val=0` falls through `best=5` (`""` prefix) and prints `"0.000 "` — fine; `val=NaN` flows through `fabs` → NaN → no condition matches → prints `"nan "`; `val=±inf` similar. These edge cases are not bugs per se but worth documenting.

**Severity:** Medium (memory leak in a stdlib helper).

**Remediation:**
1. Either (a) use a thread-local 64-byte static buffer (callers must copy the result before next call), or (b) accept a caller-provided `char *out, size_t out_len` and return the written length.
2. Document the chosen ownership rule in the rod doc-comment.
3. Consider porting the helper to pure-Nucleor (using `f64_to_str_prec`) to avoid the FFI allocation entirely.

---

### F-NUM-008 — Default unsuffixed integer literal is i64, not i32 as RFC-0015 §3.6 requires  [MEDIUM]

**Location:** Lexer / type-inference in `compiler/nucleor_s1_compiler.nr`.

**Evidence (probe `t16_lit_inference.nr`):**
```nucleor
let a = 100;             // RFC-0015 §3.6: "default i32"
let big = 3000000000;    // > i32::MAX. If default is i32, NUM-002 should fire.
print(str_from_int(big));   // 3000000000  — no diagnostic, default is i64
```
Confirms that unsuffixed integer literals fall back to i64 (the v0.1 i64-everywhere ABI), not i32 as RFC-0015 §3.6 specifies.

By contrast, `let c: i8 = 200` correctly fires NUM-002, so range-checking against an explicit declared type works; only the implicit default rule is wrong.

**Why it matters:**
- Adopters following the RFC-0015 example code expect `let count = 1000` to be i32. When they cast it `count as f32` they get the i64-to-f32 conversion (lossy at 2^24), not the i32-to-f32 conversion they expected (lossy at 2^24 as well — same threshold; the difference materializes when iterating on numeric indexes that overflow i32).
- Cross-language interop: porting Rust code where the inferred type is i32 will silently widen to i64.

**Severity:** Medium (documented language guarantee not held).

**Remediation:**
1. Either (a) implement the i32 default, or (b) amend RFC-0015 §3.6 to read "default i64" with a migration plan for the eventual i32-default future. (a) is preferred because Rust precedent matters; the migration is non-trivial because every existing program assumes i64.
2. Add NUM-002 emission for unsuffixed literals that overflow i32 in the absence of an explicit type annotation; this will surface the change at compile time for adopters during the migration.

---

### F-NUM-009 — `f64 → i64` saturation bound is `9.223e18`, leaving values in `(2^63 - 808, 2^63)` UB-adjacent  [LOW]

**Location:** `stdlib/runtime/nucleor_llvm_rt.c` lines 7935-7940.

**Evidence:**
```c
long long __nucleor_f64_to_i64(long long b) {
    double d = __nuc_b2d(b);
    if (d != d) return 0;
    if (d >  9223372036854775000.0) return 9223372036854775807LL;
    if (d < -9223372036854775000.0) return -9223372036854775807LL - 1LL;
    return (long long)d;
}
```
The bound `9223372036854775000.0` is below i64::MAX (`9223372036854775807`). For f64 values in `(9223372036854775000.0, 2^63)` the saturating clamp does NOT trigger; the cast falls into `(long long)d`. For `d` in `[2^63, +inf)` this is undefined behaviour in C (assertion failure on platforms with `-fsanitize=undefined`). In practice on x86 with `cvttsd2si`, out-of-range f64→i64 returns `0x8000000000000000` (i64::MIN), so `2^63 - ε` becomes i64::MIN instead of i64::MAX.

Probe `t12_f64_i64_boundary.nr` did not hit this gap because the synthetic operand `1.0e18 * 9.223372036854776` rounds to a representable f64 below the bound. A targeted operand could be constructed with `f64_from_bits(0x43E0000000000000)` = exactly 2^63; the current implementation returns i64::MIN for this input.

Same issue for `__nucleor_f64_to_u64` at the upper bound (`18446744073709550000.0` < `2^64`).

**Why it matters:**
- For correctly-saturating semantics promised by RFC-0015 §3.5, `2^63 as i64 = i64::MAX` should hold. Today it returns i64::MIN.
- Production adopters running with UBSan find a runtime trap.

**Severity:** Low (narrow operand window; no observed adopter hit yet).

**Remediation:**
1. Use the actually-representable bound: `0x43E0000000000000` (2^63) for the upper i64 check, comparing with `>=` rather than `>`. Concretely:
   ```c
   if (d >= 9223372036854775808.0) return 9223372036854775807LL;
   if (d <  -9223372036854775808.0) return -9223372036854775807LL - 1LL;
   ```
   Note `-2^63` IS representable in i64, so the lower clamp uses `<` (strictly less than i64::MIN).
2. For u64: `if (d >= 18446744073709551616.0) return ...UINT64_MAX...`.
3. Add boundary unit tests for `2^63 ± ulp`, `2^64 ± ulp`.

---

### F-NUM-010 — UNIT-001..005 diagnostic codes reserved but not emitted  [LOW]

**Location:** `nuc explain` table; type-checker.

**Evidence:**
RFC-0005 status: "UNIT-001..005 diagnostic codes reserved + entries in `nuc explain`. ... UNIT-001..005 emit sites are not yet wired into the type checker." Probe `t19_si_dim_check.nr` confirms that user code can build mismatched dimension vectors and cross-dimension conversions without any UNIT-* diagnostic firing.

**Why it matters:**
- Adopters reading `nuc explain UNIT-001` see the diagnostic spec and assume the check exists.
- Combined with F-NUM-002, this is the user-visible part of the same "RFC-0005 is unfulfilled" finding.

**Severity:** Low (documentation/expectation gap; F-NUM-002 is the same root cause at higher severity).

**Remediation:**
1. Either (a) wire the rod-level `dim_check_or_panic` to fire UNIT-001 at runtime in conversion entry-points (matches the F-NUM-002 stop-gap), or (b) update the `nuc explain UNIT-001..005` text to mark these as "reserved for v0.6+; not currently emitted".

---

### F-NUM-011 — `dim_check_or_panic` exists but is never wired into the unit conversion path  [NOTE]

**Location:** `stdlib/rods/units.nr` lines 180-185.

**Evidence:**
```nucleor
fn dim_check_or_panic(have: Vec<i64>, want: Vec<i64>, label: str) -> i64 {
    if dim_eq(have, want) == 1 { return 1; };
    print(str_concat("ERROR: dim_check failed at ", ...));
    panic(...);
    return 0;
}
```
The helper is implemented and exported but is not called from any other helper in the file. `unit_convert_f64`, `unit_distance_value_as`, `unit_velocity_value_as`, `unit_acceleration_value_as` all bypass it.

**Why it matters:**
The helper IS the runtime stop-gap for F-NUM-002 / F-NUM-010. It just needs callers.

**Severity:** Note (existing-but-unused mechanism).

**Remediation:**
1. In `unit_convert_f64`, look up `category(from_id)` and `category(to_id)` and call `dim_check_or_panic` before invoking `nuc_unit_convert`.
2. Same in any cross-unit helper that pivots through an SI baseline.

---

### F-NUM-012 — `unit_convert` runtime accepts unknown unit IDs and silently passes the value through unchanged (`default: return val`)  [NOTE]

**Location:** `stdlib/runtime/units_rt.c` lines 105 and 154.

**Evidence:**
```c
default: return val;
```
Both `to_si` and `from_si` use a `default` branch that returns the input unchanged. So `unit_convert_f64(42.0, 999, 1000)` returns `42.0` with no diagnostic — both 999 and 1000 are unknown unit IDs, both fall into `default`, and the round-trip is the identity.

**Why it matters:**
- Future expansion of the unit ID space (rods adding new IDs) can collide with random integers callers use as IDs.
- A typo (`unit_kHz` vs `unit_kPa` is just a 1-character delta in source; if a user passes the wrong constant, they get a silent identity conversion).

**Severity:** Note (defensive-design gap; no observed miscompute today because the rod surface always passes a known-good ID).

**Remediation:**
1. Replace `default: return val;` with `default: return NAN;` (and optionally call a `nuc_panic` FFI). The rod wrapper checks the result and emits UNIT-004 ("Unknown unit alias") via the diagnostic surface RFC-0005 already reserved.
2. Document the rule in the rod header comment.

---

### F-NUM-013 — `nuc_unit_si_prefix` does not handle `val=0` cleanly (default `best=5` is fine, but the loop never breaks for sub-femto values)  [NOTE]

**Location:** `stdlib/runtime/units_rt.c` lines 170-175.

**Evidence:**
For `val=0`, the loop computes `0/scales[i]` for each i, never satisfies `>= 1`, defaults to `best=5` (no prefix), prints `"0.000 X"`. Fine.

For `val=1e-20`, no prefix matches (smallest is `f` = 1e-15). Loop falls through, `best=5`, prints `"0.000 X"` — silently drops the value.

For `val=NaN` or `val=±inf`, `fabs` propagates, `0/...` cases yield NaN/inf, `>= 1 && < 1000` is false, falls through to `best=5`, then `snprintf` prints `"nan X"` or `"inf X"`.

**Why it matters:**
- Cosmetic — telemetry output for sub-femto values is misleading.

**Severity:** Note.

**Remediation:**
1. If `absval == 0 || absval < 1e-15`, use scientific notation directly.
2. If `!isfinite(absval)`, print `nan` / `±inf` without a prefix.

---

## Per-type × axis matrix

| Type \ Axis | Functional | Boundary | Coercions | Float specials | Determinism | Const-fold | Cast/narrow |
|---|---|---|---|---|---|---|---|
| i64 | OK | OK (panic on +1@MAX, /-1@MIN, %0, /0) | OK (no implicit; explicit `as`) | n/a | OK | OK (NUM-021 fires on overflow) | f64→i64 OK at most boundaries; F-NUM-009 narrow window |
| i32 | OK | OK (panic on inner-i32 overflow `1e6*5e3`) | F-NUM-004: i32+u32 silent | n/a | OK | OK | OK |
| i16, i8 | OK for explicit decls | NUM-002 fires on out-of-range literal | F-NUM-004 same | n/a | OK | OK | F-NUM-001 CRITICAL: f64→{i8,i16} silently returns 0 |
| u64, u32 | OK | OK | F-NUM-004 same | n/a | OK | NUM-021 fires on `0u32 - 1` | OK |
| u16, u8 | OK | NUM-002 fires on lit OOR; `as_u8(256)=0` truncation OK | F-NUM-004 same | n/a | OK | OK | F-NUM-001 CRITICAL: f64→{u8,u16} silently returns 0 |
| f64 | OK | div/0 → ±inf, 0/0 → NaN, all per IEEE | n/a | NaN!=NaN ✓, NaN<x = false ✓, +0==-0 ✓ | bit-exact across runs (probe t22) | bit-exact vs Python (probe t23) | F-NUM-001 to narrow; F-NUM-009 to i64 narrow window |
| f32 | OK (f32_add/sub/mul/div via numeric rod) | overflow → ±inf (probe t21) | n/a | (not directly tested but uses C runtime) | (relies on numeric_rt) | OK | F-NUM-001 to narrow |
| Subnormals | f64 supported; f64=1e-300/1e20 yields valid subnormal `0x07E8` (probe t25) | OK | n/a | matches Python | OK | OK | n/a |
| FMA | n_f64_mul_add via numeric_rt fma()  | OK (probe t24) | n/a | OK | OK | n/a | n/a |
| Bit-shift | bit_shift_left/right work for n in [0,63] | F-NUM-003 CRITICAL: UB for n>=64, n<0 | n/a | n/a | OK in valid range | n/a | n/a |

---

## SI dimensional cases

| Case | Result | Verdict |
|---|---|---|
| 2.5 m → mm | 2500 | OK |
| 100 °C → K | 373.15 | OK |
| 32 °F → °C | 0 | OK |
| -40 °C → °F | -40 | OK (fix-point) |
| 1 hr → s | 3600 | OK |
| 1 lb → kg | 0.453592 | OK |
| 1 oz → kg | 0.0283495 | F-NUM-006: 0.028349523 vs spec 0.028349523125 |
| 16 oz → lb | 1.0 (lucky cancellation) | OK by accident |
| 1 rad → deg → rad | round-trip exact | OK |
| 0 K → °C → K | round-trip exact 0 | OK |
| dim_eq(m, s) | 0 | OK |
| **unit_convert_f64(10, m, s)** | 10 | **F-NUM-002 CRITICAL: cross-dim silent** |
| **unit_convert_f64(100, Pa, m)** | 100 | **F-NUM-002 CRITICAL** |
| **unit_convert_f64(1, J, Hz)** | 1 | **F-NUM-002 CRITICAL** |
| **unit_convert_f64(1, V, s)** | 1 | **F-NUM-002 CRITICAL** |
| **unit_convert_f64(1, kWh, deg)** | 2.063e8 | **F-NUM-002 CRITICAL** |
| unit_distance_add(&dist, &time) | type error (struct types differ) | OK at .nr surface |

---

## Differential vs Python (bit-exact f64)

| Calculation | Nucleor (f64 bits) | Python (f64 bits) | Match |
|---|---|---|---|
| Σ 1/i for i=1..1000 | `4620113909371954712` | `4620113909371954712` | ✓ |
| 0.1 + 0.2 (compile-time fold) | `4599075939470750516` | `4599075939470750516` | ✓ |
| 0.1 + 0.2 (runtime) | `4599075939470750516` | `4599075939470750516` | ✓ |
| `(i64)16777217 as f32` | `0x4B800000` (1266679808) | `0x4B800000` (1266679808) | ✓ |
| `1.0e-300 / 1.0e20` (subnormal) | bits `2024` (`0x7E8`) | `1e-320`-equivalent subnormal | ≈ (representation OK; print precision differs) |

---

## Determinism

Same numeric program twice in the same process produces bit-exact outputs (probe t22). RFC-NRT-003 (`verify-reproducible`) ships in the v1.0 binary. Cross-run determinism not exercised here (Layer 6/7 concern).

---

## Constant folding correctness

`(i64::MAX - 1) + 1 == i64::MAX` const-folds correctly without panic (probe t23). `(i64::MAX + 1)` triggers NUM-021 at compile time (probe t02). `0.1 + 0.2` const-folds to the same f64 bit pattern as runtime (probe t23). No fold-vs-runtime divergence observed.

`-1 as u32 = 4294967295` runtime path (probe t29) matches Rust spec, but the const-fold path emits NUM-021 (probe t29 first version with a literal `0u32 - 1` — strictly speaking that path is over-strict per Rust precedent, where `(0u32 - 1) wrapping_sub` is a discoverable identity; here NUM-021 errors on the const expression). Note rather than finding.

---

## Summary

**3 Critical, 1 High, 4 Medium, 1 Low, 4 Notes.**

The two showstoppers for v1.0 numeric correctness are:

1. **F-NUM-001** — `f64/f32 as {i8,u8,i16,u16}` silently returns the bit-pattern's low byte(s) instead of saturating-rounding the value. ML quantization, image processing, and audio code that targets narrow integer storage hit this on every cast. The fix is mechanical (four runtime helpers + a dispatch table extension).

2. **F-NUM-002** — `unit_convert_f64` accepts cross-dimensional conversions silently, returning numerically meaningless f64 outputs. RFC-0005 was created explicitly to prevent this bug class. The runtime stop-gap (category-tagging the existing 10-stride unit ID layout + invoking the already-implemented `dim_check_or_panic`) is small.

**F-NUM-003** (bit-shift UB for count ≥ 64 / < 0) rounds out the Critical set; downstream of the C runtime not bounding the shift count.

**F-NUM-004** (mixed-width arithmetic implicit) is the documented v1.0 deviation from RFC-0015 strict mode; remediation is either ship enforcement or amend the RFC.

The remaining Medium / Low / Note findings are precision constants (F-NUM-006), a memory leak (F-NUM-007), the i32-default-literal omission (F-NUM-008), the f64→i64 saturation bound (F-NUM-009), and unwired-but-implemented diagnostic / dim-check infrastructure (F-NUM-010..013).

Float behaviour (NaN, ±inf, ±0, subnormals, FMA, rounding modes, determinism, const-fold) is **uniformly correct** and matches Python bit-for-bit on the differential cases tested.
