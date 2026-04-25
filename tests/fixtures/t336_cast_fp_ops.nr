// T3.36 (v0.3.61) — regression test for the as-cast-result-
// in-binop codegen bug fixed in v0.3.61.
//
// Pre-v0.3.61: `(make_int() as f64) + (make_int() as f64)`
// returned -0.0 because both operands were as-casts (kind 99)
// and that kind wasn't in binop_float_type's enumeration.
// The cast×literal form `(i as f64) * 2.0` worked because the
// 2.0 literal forced f64 dispatch via kind 71. The cast×var
// form `(i as f64) * f` worked because the var f was f64. But
// cast×cast fell through to integer add.
//
// Production-relevant for control loops mixing integer
// counters/timestamps with floating-point computations:
// `(tick as f64) * dt + (frame as f64) * frame_period`.
//
// Verify gate (T3.36) asserts cast results compose correctly
// in inline binops across the four mixed shapes.

fn make_int() -> i64 { return 7; }
fn make_two() -> f64 { return 2.0; }

fn main() -> i64 {
    let i: i64 = 4;
    let f: f64 = 3.0;

    // cast × literal (worked pre-v0.3.61 via kind==71 dispatch)
    let r1: f64 = (i as f64) * 2.0;
    print_f64(r1);   // 8.0

    // cast × var f64 (worked pre-v0.3.61 via kind==3 dispatch)
    let r2: f64 = (i as f64) + f;
    print_f64(r2);   // 7.0

    // cast × cast (BROKEN pre-v0.3.61, fixed in v0.3.61)
    let r3: f64 = (i as f64) + (make_int() as f64);
    print_f64(r3);   // 11.0

    // cast × fn-call (mixed kind 99 + kind 7)
    let r4: f64 = (i as f64) * make_two();
    print_f64(r4);   // 8.0

    // Two casts of the SAME fn-call (the original bug shape)
    let r5: f64 = (make_int() as f64) + (make_int() as f64);
    print_f64(r5);   // 14.0

    return 0;
}
