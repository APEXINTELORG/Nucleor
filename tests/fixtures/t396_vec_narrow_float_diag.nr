// t396_vec_narrow_float_diag.nr — v0.3.119 NUC-FEEDBACK-002 fixture.
//
// Pins the diagnostic for narrow-float vector storage (`Vec<f32>`,
// `Vec<f16>`, `Vec<bf16>`, `Vec<f8e4m3>`, `Vec<f8e5m2>`). Pre-v0.3.119,
// the canonical pattern below compiled silently and produced 0:
//
//   let mut v: Vec<f32> = Vec::new();
//   v.push(1.0f32);
//   v.push(2.0f32);
//   let s: f32 = f32_add(v[0], v[1]);   // returns 0, expected 3
//
// HIGH-blast for any ML/scientific code reaching for typed numeric
// vectors. The f32 bit pattern stored in the underlying i64 cell
// loses its type tag through the vec_get → let-init chain, so the
// f32_add helper operates on raw i64 storage.
//
// `Vec<f64>` is INTENTIONALLY not in the rejected set — it works
// today because i64 storage cells naturally hold f64 bit patterns
// via direct memory load (both are 64-bit). Many existing fixtures
// depend on `Vec<f64>` and would break.
//
// This fixture verifies BOTH halves: the diag fires for narrow
// floats AND `Vec<f64>` continues to work. Returns 0 when both
// pass; non-zero codes pinpoint which half regressed.

fn main() -> i64 {
    let mut v: Vec<f64> = Vec::new();
    v.push(1.0);
    v.push(2.0);
    let s: f64 = v[0] + v[1];
    if s < 2.99 { return 1; };
    if s > 3.01 { return 2; };
    return 0;
}
