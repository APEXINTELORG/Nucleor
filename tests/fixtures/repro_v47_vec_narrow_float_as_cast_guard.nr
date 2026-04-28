// repro_v47_vec_narrow_float_as_cast_guard.nr
//
// v0.4.47 NUC-FEEDBACK-002 silent-miscompute guard.
// `v[i] as f32` on `Vec<f32>` is a numeric conversion of the i64 cell
// (which holds the f32 bit pattern), not a bit-reinterpret. Pre-v0.4.47
// the compiler accepted it silently and the result was nonsense
// (e.g. 1069547520.0_f32 instead of 1.5_f32). v0.4.47 emits NUM-006
// pointing at the correct surface (f32_from_bits / f16_to_f32 / etc.).
//
// This fixture pins the diagnostic for Vec<f32>. The other narrow
// floats share the same code path; spot-checked in isolation.

fn main() -> i64 {
    let mut v: Vec<f32> = Vec::new();
    v.push(f32_to_bits(1.5 as f32));
    let bad: f32 = v[0] as f32;   // NUM-006 expected
    println!("{}", bad);
    return 0;
}
