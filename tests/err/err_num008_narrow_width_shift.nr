// EXPECT: error[NUM-008] shift amount 32 is out of range for i32
// err_num008_narrow_width_shift — v0.6.37 negative fixture
// closes probe finding 2026-05-01-num-008-shift-only-checks-i64-
// not-narrow-widths. Pre-fix NUM-008 only checked the i64 bound
// (0..=63) — `let a: i32 = 1 << 32;` silently lowered to LLVM
// `shl i32` with shift amount 32 (UB / poison) and returned 0
// at runtime. v0.6.37 derives the bound from the LHS type's width
// (i8=8, i16=16, i32=32, i64=64) and fires NUM-008 at compile
// time for narrow widths.

fn main() -> i32 {
    let a: i32 = 1 << 32;
    print_int(a);
    0
}
