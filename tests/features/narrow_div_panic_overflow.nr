// Positive coverage for v0.5.10 narrow-width panic_div helpers.
// Confirms regular i32 div+rem returns correct values (no false
// panic), and that mixed widths (i16, i8) compile + run.
//
// EXPECT: build success, runtime exit 0, prints in order:
//   25 (100/4)
//   2  (17%5)
//   16383 (32767/2 i16, truncating)
//   42 (84/2 i8)
//   OK narrow_div_panic_overflow

fn main() -> i32 {
    let a32: i32 = 100;
    let b32: i32 = 4;
    print_int(a32 / b32);

    let c32: i32 = 17;
    let d32: i32 = 5;
    print_int(c32 % d32);

    let a16: i16 = 32767;
    let b16: i16 = 2;
    print_int((a16 / b16) as i32);

    let a8: i8 = 84;
    let b8: i8 = 2;
    print_int((a8 / b8) as i32);

    print("OK narrow_div_panic_overflow");
    0
}
