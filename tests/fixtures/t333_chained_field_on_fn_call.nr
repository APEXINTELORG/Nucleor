// T3.33 (v0.3.58) — regression test for the
// chained-field-access-on-fn-call-result codegen bug fixed
// in v0.3.58.
//
// Pre-v0.3.58: `make_v().x` (where `make_v` returns a
// struct) failed compilation with `ERROR: cannot resolve
// field access type for .x`. Root cause: expr_struct_type
// didn't handle kind 7 (fn call) — same bug class as
// v0.3.54's binop_float_type miss. v0.3.58 added the kind==7
// branch reading the v0.3.54 `__fnret_<NAME>` sym entry.
//
// This is a production-relevant pattern. Builder/factory
// shapes pervade robotics code: pose builders, geometry
// constructors, sensor-frame helpers all return a struct
// that callers immediately destructure via dot access.
//
// Verify gate (T3.33) asserts the chained access compiles
// AND produces the correct sum.

#[repr(C)]
struct V3 { x: f64, y: f64, z: f64 }

fn make_v() -> V3 { return V3 { x: 1.5, y: 2.5, z: 3.5 }; }

fn main() -> i64 {
    // Baseline: let-bound struct (works pre-v0.3.58 too).
    let v: V3 = make_v();
    let r1: f64 = v.x + v.y;
    print_f64(r1);   // 4.0

    // Chained: field access on fn-call result. v0.3.58 fix.
    let r2: f64 = make_v().x + make_v().y;
    print_f64(r2);   // 4.0

    // Field access on fn-call used standalone (no binop).
    let r3: f64 = make_v().z;
    print_f64(r3);   // 3.5

    return 0;
}
