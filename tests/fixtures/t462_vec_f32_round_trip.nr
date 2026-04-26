// t462_vec_f32_round_trip.nr -- v0.3.204 NUC-FEEDBACK-002 deeper-fix.
//
// Pre-v0.3.204, `let v: Vec<f32> = ...;` was a TYP-009 hard error
// (added v0.3.180 because the round-trip silently miscomputed when
// adopters wrote `f32_add(v[0], v[1])` -- the f32 bit pattern in the
// underlying i64 cell got numerically reinterpreted as integer
// arithmetic).
//
// Verified deep-fix path (this fixture):
//   1. Push f32 values (the i64 register holds the f32 bit pattern in
//      its low 32 bits) into the Vec.
//   2. Read back with `f32_from_bits(v[i])` -- the explicit bit-cast
//      surface in the runtime that reinterprets without numerical
//      conversion.
//   3. Use the typed f32 helpers (`f32_add`, `f32_mul`, etc.) on
//      the read-back values.
//   4. Display via `println!("{}", val)` which now dispatches to
//      `__nucleor_f32_to_str` (added in this same release).
//
// Why `v[i] as f32` doesn't work (and why we need f32_from_bits):
// the `as` cast assumes the source is a numeric value. `v[i]` is i64
// holding the bit pattern of an f32; numeric-casting it would convert
// the integer value to float (e.g., bit pattern 0x3FC00000 = 1069547520
// would cast to 1069547520.0f32, NOT to 1.5f32). f32_from_bits is the
// reinterpret-cast surface; `as` stays as numeric conversion.
//
// f16 / bf16 / f8eXmY still hard-error because they have no runtime
// pack/unpack helpers (NUC-FEEDBACK-002 follow-on, queued).

fn main() -> i64 {
    let mut v: Vec<f32> = Vec::new();
    let x1: f32 = 1.5 as f32;
    let x2: f32 = 2.5 as f32;
    let x3: f32 = 3.5 as f32;
    // v0.3.211: `f32 as i64` now NUMERIC-truncates (Rust semantic).
    // For bit-pattern transit into Vec<i64>-style storage, use the
    // explicit reinterpret surface f32_to_bits.
    v.push(f32_to_bits(x1));
    v.push(f32_to_bits(x2));
    v.push(f32_to_bits(x3));

    let a: f32 = f32_from_bits(v[0]);
    let b: f32 = f32_from_bits(v[1]);
    let c: f32 = f32_from_bits(v[2]);
    let sum: f32 = f32_add(f32_add(a, b), c);
    println!("{}", sum);   // expect 7.5
    println!("{}", a);     // expect 1.5
    println!("{}", b);     // expect 2.5
    println!("{}", c);     // expect 3.5
    return 0;
}
