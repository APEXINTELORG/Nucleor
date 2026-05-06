// =====================================================
// rods/numeric — RFC-0015 numeric type operations
// =====================================================
// Import: import "stdlib/rods/numeric.nr"
//
// Provides: explicit-overflow integer arithmetic, narrow integer
//   truncation casts, f32 / bf16 / f16 / f8 software-emulated math,
//   per-width print helpers, hex/bin formatters.
//
// All values pass as i64 cells (storage uniform until v0.4 generic
// monomorphization). Float types pack their bit-pattern in the low
// N bits.
// =====================================================

#cfile "numeric_rt.c"

extern fn nuc_numeric_rounding_nearest() -> i64;
extern fn nuc_numeric_rounding_downward() -> i64;
extern fn nuc_numeric_rounding_upward() -> i64;
extern fn nuc_numeric_rounding_toward_zero() -> i64;
extern fn nuc_numeric_get_rounding_mode() -> i64;
extern fn nuc_numeric_set_rounding_mode(mode: i64) -> i64;
extern fn nuc_numeric_f64_next_up(x: i64) -> i64;
extern fn nuc_numeric_f64_next_down(x: i64) -> i64;
extern fn nuc_numeric_f64_mul_add(a: i64, b: i64, c: i64) -> i64;
extern fn nuc_numeric_f32_mul_add(a: i64, b: i64, c: i64) -> i64;

// ---- Overflow-mode integer arithmetic ----
fn n_wrapping_add(a: i64, b: i64) -> i64 { return wrapping_add(a, b); }
fn n_wrapping_sub(a: i64, b: i64) -> i64 { return wrapping_sub(a, b); }
fn n_wrapping_mul(a: i64, b: i64) -> i64 { return wrapping_mul(a, b); }
fn n_saturating_add(a: i64, b: i64) -> i64 { return saturating_add(a, b); }
fn n_saturating_sub(a: i64, b: i64) -> i64 { return saturating_sub(a, b); }
fn n_saturating_mul(a: i64, b: i64) -> i64 { return saturating_mul(a, b); }
fn n_checked_add(a: i64, b: i64) -> i64 { return checked_add(a, b); }
fn n_checked_sub(a: i64, b: i64) -> i64 { return checked_sub(a, b); }
fn n_checked_mul(a: i64, b: i64) -> i64 { return checked_mul(a, b); }
fn n_overflow_flag() -> i64 { return checked_overflow_flag(); }

// ---- IEEE-754 rounding / fused arithmetic helpers ----
fn n_rounding_nearest() -> i64 { return nuc_numeric_rounding_nearest(); }
fn n_rounding_downward() -> i64 { return nuc_numeric_rounding_downward(); }
fn n_rounding_upward() -> i64 { return nuc_numeric_rounding_upward(); }
fn n_rounding_toward_zero() -> i64 { return nuc_numeric_rounding_toward_zero(); }
fn n_get_rounding_mode() -> i64 { return nuc_numeric_get_rounding_mode(); }
fn n_set_rounding_mode(mode: i64) -> i64 { return nuc_numeric_set_rounding_mode(mode); }
fn n_f64_next_up(x: i64) -> i64 { return nuc_numeric_f64_next_up(x); }
fn n_f64_next_down(x: i64) -> i64 { return nuc_numeric_f64_next_down(x); }
fn n_f64_mul_add(a: i64, b: i64, c: i64) -> i64 { return nuc_numeric_f64_mul_add(a, b, c); }
fn n_f32_mul_add(a: i64, b: i64, c: i64) -> i64 { return nuc_numeric_f32_mul_add(a, b, c); }

// ---- Narrow integer truncation casts ----
fn n_as_i8(v: i64) -> i64 { return as_i8(v); }
fn n_as_i16(v: i64) -> i64 { return as_i16(v); }
fn n_as_i32(v: i64) -> i64 { return as_i32(v); }
fn n_as_u8(v: i64) -> i64 { return as_u8(v); }
fn n_as_u16(v: i64) -> i64 { return as_u16(v); }
fn n_as_u32(v: i64) -> i64 { return as_u32(v); }
fn n_as_u64(v: i64) -> i64 { return as_u64(v); }

// ---- f32 distinct compute ----
fn f32(x: i64) -> i64 { return f32_from_int(x); }
fn f32_int(b: i64) -> i64 { return f32_to_int(b); }
fn f32_plus(a: i64, b: i64) -> i64 { return f32_add(a, b); }
fn f32_minus(a: i64, b: i64) -> i64 { return f32_sub(a, b); }
fn f32_times(a: i64, b: i64) -> i64 { return f32_mul(a, b); }
fn f32_divides(a: i64, b: i64) -> i64 { return f32_div(a, b); }

// ---- bf16 / f16 ergonomic wrappers ----
fn bf16(x: i64) -> i64 { return bf16_from_f32(f32_from_int(x)); }
fn bf16_int(b: i64) -> i64 { return f32_to_int(bf16_to_f32(b)); }
fn f16(x: i64) -> i64 { return f16_from_f32(f32_from_int(x)); }
fn f16_int(b: i64) -> i64 { return f32_to_int(f16_to_f32(b)); }

// ---- Per-width display ----
fn n_print_i8(v: i64) -> i64 { return print_i8(v); }
fn n_print_i16(v: i64) -> i64 { return print_i16(v); }
fn n_print_i32(v: i64) -> i64 { return print_i32(v); }
fn n_print_u8(v: i64) -> i64 { return print_u8(v); }
fn n_print_u16(v: i64) -> i64 { return print_u16(v); }
fn n_print_u32(v: i64) -> i64 { return print_u32(v); }
fn n_print_u64(v: i64) -> i64 { return print_u64(v); }
fn n_print_f32(v: i64) -> i64 { return print_f32(v); }
fn n_print_hex(v: i64) -> i64 { return print_hex(v); }
fn n_print_bin(v: i64) -> i64 { return print_bin(v); }

// ---- Type-width queries (compile-time-known constants) ----
fn n_size_i8() -> i64 { return 1; }
fn n_size_i16() -> i64 { return 2; }
fn n_size_i32() -> i64 { return 4; }
fn n_size_i64() -> i64 { return 8; }
fn n_size_u8() -> i64 { return 1; }
fn n_size_u16() -> i64 { return 2; }
fn n_size_u32() -> i64 { return 4; }
fn n_size_u64() -> i64 { return 8; }
fn n_size_f8() -> i64 { return 1; }
fn n_size_f16() -> i64 { return 2; }
fn n_size_bf16() -> i64 { return 2; }
fn n_size_f32() -> i64 { return 4; }
fn n_size_f64() -> i64 { return 8; }

// ---- Range constants (i64 representable) ----
fn n_max_u8() -> i64 { return 255; }
fn n_max_u16() -> i64 { return 65535; }
fn n_max_u32() -> i64 { return 4294967295; }
fn n_max_i8() -> i64 { return 127; }
fn n_min_i8() -> i64 { return 0 - 128; }
fn n_max_i16() -> i64 { return 32767; }
fn n_min_i16() -> i64 { return 0 - 32768; }
fn n_max_i32() -> i64 { return 2147483647; }
fn n_min_i32() -> i64 { return 0 - 2147483648; }
