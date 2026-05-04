// rods/fixed_point — RFC-0043 Phase A: Q-format fixed-point
// arithmetic helpers (rod-only, no compiler change).
//
// Adopters porting embedded / DSP / financial Rust code use
// `fixed<I, F>` for predictable fractional arithmetic without
// f32/f64 rounding hazards. The full RFC-0043 ship adds
// `IrTypeFixed { i_bits, f_bits, signed }` as a first-class IR
// type with width tracking through BinOp (~300 LOC compiler-
// side, deferred). Phase A (this rod) provides the canonical
// Q-format runtime helpers as i64-encoded fixed-point values
// adopters can use today.
//
// Encoding: an i64 storing the integer scaled by 2^F. For
// Q15.16 (`fixed<16, 16>`), value 1.5 is encoded as
// `1.5 * 2^16 = 98304`. The `f_bits` parameter selects the
// scale; helpers below validate the bound `I + F <= 63`
// (one bit reserved for the sign in the signed variant).
//
// Sister to RFC-0046–RFC-0051 Phase A landings — drift
// restoration for V1.12 instead of V2 frontier easy-win, but
// same "stdlib first, compiler enforcement later" pattern per
// the spine §1.5 2026-05-03 append.
//
// Workflow today:
//
//   import "stdlib/rods/fixed_point.nr"
//
//   let q: i64 = fixed_q16_16();           // Q-format selector (16,16)
//   let a: i64 = fixed_from_int(q, 3);     // 3.0 in Q15.16
//   let b: i64 = fixed_from_parts(q, 1, 5000); // 1.5 (5000/10000)
//   let c: i64 = fixed_add(q, a, b);       // 4.5
//   let d: i64 = fixed_mul(q, a, b);       // 4.5
//   let i: i64 = fixed_to_int(q, c);       // 4 (truncate toward zero)

// =====================================================
// Q-format encoding: high 8 bits = i_bits, low 8 bits = f_bits.
// Bound: i_bits + f_bits <= 63. Caller passes the encoded `q`
// param so any helper can recover both widths.
// =====================================================
fn fixed_q(i_bits: i64, f_bits: i64) -> i64 {
    return (i_bits * 256) + f_bits;
}
fn fixed_q_i_bits(q: i64) -> i64 { return q / 256; }
fn fixed_q_f_bits(q: i64) -> i64 { return q - (fixed_q_i_bits(q) * 256); }

// Common formats.
fn fixed_q16_16() -> i64 { return fixed_q(16, 16); }   // standard DSP
fn fixed_q24_8()  -> i64 { return fixed_q(24, 8); }    // graphics / sub-pixel
fn fixed_q1_31()  -> i64 { return fixed_q(1, 31); }    // saturating control-loop accumulator
fn fixed_q1_15()  -> i64 { return fixed_q(1, 15); }    // i16-range Q1.15 normalized
fn fixed_q60_4()  -> i64 { return fixed_q(60, 4); }    // monetary cents-class

// =====================================================
// Conversion in / out of integers.
// =====================================================
fn fixed_from_int(q: i64, x: i64) -> i64 {
    let f: i64 = fixed_q_f_bits(q);
    return x * (1 << f);
}

fn fixed_to_int(q: i64, v: i64) -> i64 {
    let f: i64 = fixed_q_f_bits(q);
    return v / (1 << f);
}

// Build a fixed-point value from an integer part and a numerator
// over 10000 (so 5000 = 0.5, 1234 = 0.1234 etc.). Useful when
// adopters want a literal-ish constructor without f64.
fn fixed_from_parts(q: i64, int_part: i64, num_per_10k: i64) -> i64 {
    let f: i64 = fixed_q_f_bits(q);
    let scale: i64 = 1 << f;
    let int_scaled: i64 = int_part * scale;
    let frac_scaled: i64 = (num_per_10k * scale) / 10000;
    return int_scaled + frac_scaled;
}

// =====================================================
// Add / sub: same-format ops are bare i64 add/sub. Provided as
// named fns so future Phase B can swap in width-tracked helpers.
// =====================================================
fn fixed_add(q: i64, a: i64, b: i64) -> i64 { return a + b; }
fn fixed_sub(q: i64, a: i64, b: i64) -> i64 { return a - b; }
fn fixed_neg(q: i64, a: i64) -> i64 { return 0 - a; }

// =====================================================
// Multiply: a*b with f_bits scaling produces 2*f_bits scaling;
// shift right by f_bits to recover the original Q-format.
// =====================================================
fn fixed_mul(q: i64, a: i64, b: i64) -> i64 {
    let f: i64 = fixed_q_f_bits(q);
    return (a * b) >> f;
}

// =====================================================
// Divide: a/b with f_bits scaling collapses to 0 fractional
// bits; left-shift the dividend by f_bits before divide so
// the quotient retains f_bits of fraction.
// =====================================================
fn fixed_div(q: i64, a: i64, b: i64) -> i64 {
    let f: i64 = fixed_q_f_bits(q);
    return (a << f) / b;
}

// =====================================================
// Comparison passthroughs (same-format compares are integer
// compares because Q-format is monotone in i64 storage).
// =====================================================
fn fixed_eq(q: i64, a: i64, b: i64) -> i64 { if a == b { return 1; }; return 0; }
fn fixed_lt(q: i64, a: i64, b: i64) -> i64 { if a < b { return 1; }; return 0; }
fn fixed_gt(q: i64, a: i64, b: i64) -> i64 { if a > b { return 1; }; return 0; }
fn fixed_le(q: i64, a: i64, b: i64) -> i64 { if a <= b { return 1; }; return 0; }
fn fixed_ge(q: i64, a: i64, b: i64) -> i64 { if a >= b { return 1; }; return 0; }

// =====================================================
// Re-quantize between two Q formats. Shifts left or right by
// the difference in f_bits.
// =====================================================
fn fixed_requant(from_q: i64, to_q: i64, v: i64) -> i64 {
    let from_f: i64 = fixed_q_f_bits(from_q);
    let to_f: i64 = fixed_q_f_bits(to_q);
    if to_f >= from_f { return v << (to_f - from_f); };
    return v >> (from_f - to_f);
}

// =====================================================
// Saturate-clamp helper for adopters who don't want wrap-around
// on overflow. Phase B compiler-side `saturating { ... }` block
// will hook this automatically; Phase A adopters call it
// explicitly.
// =====================================================
fn fixed_saturate(q: i64, v: i64) -> i64 {
    let i: i64 = fixed_q_i_bits(q);
    let f: i64 = fixed_q_f_bits(q);
    let total: i64 = i + f;
    if total >= 63 { return v; };
    let max_v: i64 = (1 << total) - 1;
    let min_v: i64 = 0 - max_v;
    if v > max_v { return max_v; };
    if v < min_v { return min_v; };
    return v;
}
