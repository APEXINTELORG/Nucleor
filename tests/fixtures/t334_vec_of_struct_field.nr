// T3.34 (v0.3.59) — regression test for the
// Vec-of-struct field-access codegen bug fixed in v0.3.59.
//
// Pre-v0.3.59: `v[0].x` (where v: Vec<V3>) failed
// compilation with `ERROR: cannot resolve field access type
// for .x`. Same bug class as v0.3.58 — expr_struct_type
// didn't handle kind 10 (Vec indexing). v0.3.59 added the
// kind==10 branch using the v0.3.55 `__fulltype_<vname>`
// sym entry that preserves the generic.
//
// This is a production-relevant pattern. Time-series of
// poses, batches of measurements, waypoint lists — all
// store structs in a Vec and index then dot-access inline.
//
// Verify gate (T3.34) asserts the indexed field access
// compiles AND produces the correct sum across the realistic
// shapes.

#[repr(C)]
struct V3 { x: f64, y: f64, z: f64 }

fn main() -> i64 {
    let mut path: Vec<V3> = Vec::new();
    path.push(V3 { x: 1.0, y: 2.0, z: 3.0 });
    path.push(V3 { x: 4.0, y: 5.0, z: 6.0 });
    path.push(V3 { x: 7.0, y: 8.0, z: 9.0 });

    // Standalone field access on indexed struct.
    let r1: f64 = path[0].x;
    print_f64(r1);   // 1.0

    // Inline binop combining two indexed-then-fielded ops.
    let r2: f64 = path[0].x + path[1].y;
    print_f64(r2);   // 6.0

    // Triangle distance shape: (path[2].x - path[0].x)^2 component.
    let dx: f64 = path[2].x - path[0].x;
    print_f64(dx);   // 6.0

    return 0;
}
