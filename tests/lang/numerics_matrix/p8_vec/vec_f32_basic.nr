// p8_vec/vec_f32_basic.nr — Phase 8: Vec stores f32 round-trip.
// Uses generic vec_* with f32 bit-patterns stored in i64 slots.

fn main() -> i32 {
    let v: i64 = vec_new();
    let one: f32 = 1.0;
    let two_five: f32 = 2.5;
    let pi_ish: f32 = 3.14;
    let _ = vec_push(v, one);
    let _ = vec_push(v, two_five);
    let _ = vec_push(v, pi_ish);
    let got: f32 = vec_get(v, 1);
    if got != two_five {
        print("FAIL: Vec f32 indexing\n");
        return 1;
    };
    print("OK vec_f32_basic\n");
    return 0;
}
