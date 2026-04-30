// RFC-0015 phase 3a regression-guard fixture. v0.4.198.
//
// Locks in the current correct behavior of narrower-than-i64
// numeric types (i8/i16/i32/u8/u16/u32) under the existing
// i64-uniform IR + narrow_via_as runtime narrowing pipeline.
//
// Future phase 3a-step-3 wiring (typed allocas + sext/trunc at
// load/store boundaries) MUST keep this fixture green. If a
// step-3 ship breaks any of these assertions, the wiring is
// wrong — revert and investigate.
//
// Each test below is a self-checking print: prints the actual
// computed value; the verify gate compares the OK marker line
// at the end.

fn main() -> i32 {
    // i16 — basic arithmetic stays bit-correct.
    let a16: i16 = 100;
    let b16: i16 = 200;
    let c16: i16 = a16 + b16;
    if c16 != 300 { print("FAIL i16 add"); return 1; };

    // i16 — overflow wraps within i16 range.
    let big16: i16 = 30000;
    let big16b: i16 = 30000;
    let wrapped: i16 = wrapping { big16 + big16b };
    if wrapped != -5536 { print("FAIL i16 wrap"); return 1; };

    // u8 — multiplication.
    let u8a: u8 = 5;
    let u8b: u8 = 10;
    let u8c: u8 = u8a * u8b;
    if u8c != 50 { print("FAIL u8 mul"); return 1; };

    // u8 — overflow wraps mod 256.
    let u8big: u8 = 200;
    let u8big2: u8 = 100;
    let u8wrap: u8 = wrapping { u8big + u8big2 };
    if u8wrap != 44 { print("FAIL u8 wrap"); return 1; };

    // i32 — explicit narrowing from i64.
    let big64: i64 = 5000000000;
    let small32: i32 = big64 as i32;
    if small32 != 705032704 { print("FAIL i32 narrow"); return 1; };

    // u16 — arithmetic and pass to print.
    let u16a: u16 = 65000;
    let u16b: u16 = 100;
    let u16c: u16 = u16a + u16b;
    if u16c != 65100 { print("FAIL u16 add"); return 1; };

    // i8 — signed range (-128..127).
    let i8a: i8 = 100;
    let i8b: i8 = 27;
    let i8c: i8 = i8a + i8b;
    if i8c != 127 { print("FAIL i8 add"); return 1; };

    // Cross-width: i32 + i64 with explicit widening cast.
    let m32: i32 = 1000;
    let m64: i64 = m32 as i64 + 2000;
    if m64 != 3000 { print("FAIL i32->i64 widen"); return 1; };

    // Cross-width: i64 narrowed to i16 explicitly.
    let big_int: i64 = 99999;
    let narrow16: i16 = big_int as i16;
    // 99999 mod 65536 = 34463; as signed i16: 34463 - 65536 = -31073
    if narrow16 != -31073 { print("FAIL i64->i16 narrow"); return 1; };

    // v0.4.210: i32/u32 typed memory ops added — completes the
    // i8/i16/i32/u8/u16/u32 narrow set. IR shape now emits
    // `alloca i32` + `load i32` + `sext i32 to i64` for these.
    let p32: i32 = 1000000;
    let q32: i32 = 2000000;
    let r32: i32 = p32 + q32;
    if r32 != 3000000 { print("FAIL i32 add"); return 1; };

    let pu32: u32 = 4000000000;
    let qu32: u32 = 200000000;
    let ru32: u32 = pu32 + qu32;
    if ru32 != 4200000000 { print("FAIL u32 add"); return 1; };

    print("OK rfc0015_phase3a_widths");
    0
}
