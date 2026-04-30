// RFC-0015 phase 3 comprehensive width-correctness fixture (v0.4.222).
//
// Locks in the end-to-end IR width-tagged numeric ops semantics
// shipped in v0.4.196..v0.4.221 across phase 3a (typed memory),
// phase 3b (narrow arith), and phase 3c (typed fn params).
//
// Coverage matrix:
//   - All 6 narrow types (i8, i16, i32, u8, u16, u32)
//   - All 5 arith ops (+ - * / %)
//   - Wrap correctness via wrapping { } (native LLVM iN modular arith)
//   - Mixed-width with explicit `as` cast
//   - Negative round-trip (signed types)
//   - Unsigned high-bit (u-types > 127 / 32767 / 2147483647)
//   - Var+var, var+lit, expr+expr (nested chain) for phase 3b
//   - Fn-param + fn-return for phase 3c
//
// Sister fixture to tests/features/rfc0015_phase3a_widths.nr (which
// covers the v0.4.196..220 set). This file is the "ALL phases done"
// regression guard — any future ship that breaks any case halts
// the verify gate immediately.

fn add_i8(a: i8, b: i8) -> i8 { a + b }
fn add_i16(a: i16, b: i16) -> i16 { a + b }
fn add_i32(a: i32, b: i32) -> i32 { a + b }
fn add_u8(a: u8, b: u8) -> u8 { a + b }
fn add_u16(a: u16, b: u16) -> u16 { a + b }
fn add_u32(a: u32, b: u32) -> u32 { a + b }

fn main() -> i32 {
    // i8 — full range (-128..127).
    let i8_pos: i8 = 100;
    let i8_neg: i8 = 0 - 50;
    if add_i8(i8_pos, i8_neg) != 50 { print("FAIL i8 add"); return 1; };
    let i8_a: i8 = 60;
    let i8_b: i8 = 70;
    let i8_wrap: i8 = wrapping { i8_a + i8_b };  // 130 → -126
    if i8_wrap != -126 { print("FAIL i8 wrap"); return 1; };

    // i16 — full range (-32768..32767).
    let i16_a: i16 = 30000;
    let i16_b: i16 = 5000;
    let i16_wrap: i16 = wrapping { i16_a + i16_b };  // 35000 → -30536
    if i16_wrap != -30536 { print("FAIL i16 wrap"); return 1; };

    // i32 — full range.
    let i32_a: i32 = 2000000000;
    let i32_b: i32 = 500000000;
    let i32_wrap: i32 = wrapping { i32_a + i32_b };  // 2.5e9 → -1.79e9
    if i32_wrap != -1794967296 { print("FAIL i32 wrap"); return 1; };

    // u8 — high-bit values (>127).
    let u8_a: u8 = 200;
    let u8_b: u8 = 100;
    let u8_wrap: u8 = wrapping { u8_a + u8_b };  // 300 mod 256 = 44
    if u8_wrap != 44 { print("FAIL u8 wrap"); return 1; };
    if add_u8(50, 70) != 120 { print("FAIL u8 fn add"); return 1; };

    // u16 — high values (>32767).
    let u16_a: u16 = 60000;
    let u16_b: u16 = 100;
    let u16_sum: u16 = u16_a + u16_b;
    if u16_sum != 60100 { print("FAIL u16 add"); return 1; };

    // u32 — high values (>2147483647).
    let u32_a: u32 = 4000000000;
    let u32_b: u32 = 200000000;
    let u32_sum: u32 = u32_a + u32_b;
    if u32_sum != 4200000000 { print("FAIL u32 add"); return 1; };

    // Cross-width via explicit as cast.
    let big: i64 = 99999;
    let narrow: i16 = big as i16;
    if narrow != -31073 { print("FAIL i64->i16 cast"); return 1; };
    let widened: i64 = (narrow as i32) as i64;
    if widened != -31073 { print("FAIL i16->i32->i64 widen"); return 1; };

    // Phase 3b nested chain — single sext at chain exit.
    let na: i16 = 100;
    let nb: i16 = 50;
    let nc: i16 = 25;
    let nested: i16 = (na + nb) + nc;
    if nested != 175 { print("FAIL nested i16 chain"); return 1; };
    let nested2: i16 = na * 2 - nb;
    if nested2 != 150 { print("FAIL nested i16 *-"); return 1; };

    // Phase 3c fn-param + return — narrow args round-trip correctly.
    if add_i32(1000000, 2000000) != 3000000 { print("FAIL i32 fn"); return 1; };
    if add_u32(2000000000, 1000000000) != 3000000000 { print("FAIL u32 fn"); return 1; };

    // Negative round-trip through fn boundary.
    let neg_in: i16 = 0 - 30;
    let neg_out: i16 = add_i16(neg_in, 10);
    if neg_out != -20 { print("FAIL neg i16 fn"); return 1; };

    // Sub/mul/div/mod for completeness on i16.
    let m_a: i16 = 100;
    let m_b: i16 = 7;
    if (m_a - m_b) != 93 { print("FAIL i16 sub"); return 1; };
    if (m_a * m_b) != 700 { print("FAIL i16 mul"); return 1; };
    if (m_a / m_b) != 14 { print("FAIL i16 div"); return 1; };
    if (m_a % m_b) != 2 { print("FAIL i16 mod"); return 1; };

    print("OK rfc0015_phase3_widths_full");
    0
}
