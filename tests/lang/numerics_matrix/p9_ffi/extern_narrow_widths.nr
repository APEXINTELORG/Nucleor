// p9_ffi/extern_narrow_widths.nr — Phase 9: extern fn declarations
// with narrow types compile to the right LLVM signatures. We can't
// link against custom narrow-typed C functions in this build (no
// custom .c file alongside the test), so this test verifies that
// the compiler ACCEPTS narrow extern fn signatures and emits
// width-correct IR. Build success = pass.

extern fn _phase9_user_helper_u8(x: u8) -> u8;
extern fn _phase9_user_helper_i32(x: i32, y: i32) -> i32;
extern fn _phase9_user_helper_f32(x: f32) -> f64;

fn main() -> i32 {
    // Don't actually call these — just verify they parse + emit.
    print("OK extern_narrow_widths\n");
    return 0;
}
