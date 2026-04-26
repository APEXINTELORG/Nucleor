// t463_vec_narrow_float_round_trip.nr -- v0.3.206 NUC-FEEDBACK-002 fully closed.
//
// All four narrow-float Vec<T> types now round-trip end-to-end.
// Pre-v0.3.206 each was either TYP-009 hard-error (f16/bf16/f8eXmY)
// or worked but couldn't be displayed (f32 -- closed v0.3.204).
//
// Round-trip patterns:
//   Vec<f32>:   v.push(x as i64)                    f32_from_bits(v[i])
//   Vec<f16>:   v.push(f16_from_f32(x as f32))      f16_to_f32(v[i])
//   Vec<bf16>:  v.push(bf16_from_f32(x as f32))     bf16_to_f32(v[i])
//   Vec<f8e4m3>: v.push(f8e4m3_from_f32(x as f32))  f8e4m3_to_f32(v[i])
//   Vec<f8e5m2>: v.push(f8e5m2_from_f32(x as f32))  f8e5m2_to_f32(v[i])
//
// Display via println!("{}", val) dispatches to the *_to_str
// runtime helper for each type.
//
// Note on precision: f8e4m3 has only 3 mantissa bits so 1.5 may
// quantize differently from 1.5_f32; this fixture asserts shape
// of the round-trip not exact equality.

fn main() -> i64 {
    // f16: ~3 decimal digits of precision
    let mut h: Vec<f16> = Vec::new();
    h.push(f16_from_f32(1.5 as f32));
    h.push(f16_from_f32(2.5 as f32));
    let h0_f32: f32 = f16_to_f32(h[0]);
    let h1_f32: f32 = f16_to_f32(h[1]);
    println!("{}", h0_f32);   // expect ~1.5
    println!("{}", h1_f32);   // expect ~2.5

    // bf16: ~2 decimal digits of precision (8-bit exp like f32)
    let mut b: Vec<bf16> = Vec::new();
    b.push(bf16_from_f32(0.5 as f32));
    b.push(bf16_from_f32(4.0 as f32));
    let b0_f32: f32 = bf16_to_f32(b[0]);
    let b1_f32: f32 = bf16_to_f32(b[1]);
    println!("{}", b0_f32);   // expect ~0.5
    println!("{}", b1_f32);   // expect ~4

    // f8e4m3: ~1 decimal digit, exact for small powers of 2
    let mut e3: Vec<f8e4m3> = Vec::new();
    e3.push(f8e4m3_from_f32(2.0 as f32));
    e3.push(f8e4m3_from_f32(8.0 as f32));
    let e30_f32: f32 = f8e4m3_to_f32(e3[0]);
    let e31_f32: f32 = f8e4m3_to_f32(e3[1]);
    println!("{}", e30_f32);  // expect 2
    println!("{}", e31_f32);  // expect 8

    // f8e5m2: ~1 decimal digit, wider exp range
    let mut e5: Vec<f8e5m2> = Vec::new();
    e5.push(f8e5m2_from_f32(0.25 as f32));
    e5.push(f8e5m2_from_f32(64.0 as f32));
    let e50_f32: f32 = f8e5m2_to_f32(e5[0]);
    let e51_f32: f32 = f8e5m2_to_f32(e5[1]);
    println!("{}", e50_f32);  // expect 0.25
    println!("{}", e51_f32);  // expect 64
    return 0;
}
