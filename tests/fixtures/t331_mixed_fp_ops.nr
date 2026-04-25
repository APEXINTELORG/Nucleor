// T3.31 (v0.3.56) — production-coverage lock for f64 inline
// binops with MIXED operand kinds.
//
// v0.3.53/v0.3.54/v0.3.55 fixed each operand kind in
// isolation (struct field, fn-call result, Vec indexing).
// This fixture exercises the realistic production patterns
// where two DIFFERENT operand kinds appear in the same
// binop. All five combinations probed at v0.3.56 verified
// to compute correctly post the three earlier fixes.
//
// Locking these explicitly so a future codegen change that
// breaks one of the cross-kind paths can't slip through —
// the silent-miscompilation class is structurally closed
// for the AST kinds production code actually uses.
//
// Verify gate (T3.31) asserts each of the five mixed-form
// ops prints the mathematically correct value:
//   field × fn-call:    v.x * make_one()        =  3
//   field × vec[i]:     v.x * a[0]              =  6
//   fn-call × vec[i]:   make_one() * a[1]       =  5
//   (cast) × field:     (7 as f64) * v.x        = 21
//   (cast) × vec[i]:    (4 as f64) * a[1]       = 20

#[repr(C)]
struct V { x: f64, y: f64 }

fn make_one() -> f64 { return 1.0; }

fn main() -> i64 {
    let v: V = V { x: 3.0, y: 4.0 };
    let mut a: Vec<f64> = Vec::new();
    a.push(2.0);
    a.push(5.0);

    let r1: f64 = v.x * make_one();         // field × fn-call → 3
    print_f64(r1);
    let r2: f64 = v.x * a[0];               // field × vec[i] → 6
    print_f64(r2);
    let r3: f64 = make_one() * a[1];        // fn-call × vec[i] → 5
    print_f64(r3);
    let i: i64 = 7;
    let r4: f64 = (i as f64) * v.x;         // (cast) × field → 21
    print_f64(r4);
    let j: i64 = 4;
    let r5: f64 = (j as f64) * a[1];        // (cast) × vec[i] → 20
    print_f64(r5);
    return 0;
}
