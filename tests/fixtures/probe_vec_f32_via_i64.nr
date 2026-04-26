// Probe: does Vec<f32> actually work via i64 storage + manual cast?
// If yes, the TYP-009 hard error is over-conservative.
fn main() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    let x1: f32 = 1.5 as f32;
    let x2: f32 = 2.5 as f32;
    let x3: f32 = 3.5 as f32;
    // v0.3.211: `f32 as i64` now NUMERIC-truncates. Use f32_to_bits for transit.
    v.push(f32_to_bits(x1));
    v.push(f32_to_bits(x2));
    v.push(f32_to_bits(x3));

    // Read back: i64 cells hold f32 bit patterns, use f32_from_bits to
    // reinterpret without numeric conversion (which `as f32` would do).
    let a: f32 = f32_from_bits(v[0]);
    let b: f32 = f32_from_bits(v[1]);
    let c: f32 = f32_from_bits(v[2]);
    let sum: f32 = f32_add(f32_add(a, b), c);
    println!("{}", sum);  // expect 7.5
    return 0;
}
