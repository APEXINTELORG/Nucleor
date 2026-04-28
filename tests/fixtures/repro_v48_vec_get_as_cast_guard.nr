// repro_v48_vec_get_as_cast_guard.nr
//
// v0.4.48 NUC-FEEDBACK-002 silent-miscompute guard extended.
// Same hazard as v0.4.47 (`v[i] as f32` numeric-casts the i64 cell)
// but for the function-call form `vec_get(v, i) as f32`. Adopters
// who reach for vec_get / vec_first / vec_last / vec_pop instead
// of bracket indexing should hit the same NUM-006 diagnostic.
//
// This fixture pins vec_get; vec_first/vec_last/vec_pop share the
// same code path.

fn main() -> i64 {
    let mut v: Vec<f32> = Vec::new();
    v.push(f32_to_bits(1.5 as f32));
    let bad: f32 = vec_get(v, 0) as f32;   // NUM-006 expected
    println!("{}", bad);
    return 0;
}
