// stdlib/rods/kdt — `*_f64` ergonomic wrappers.
//
// v0.4.263 bundle (with csv_table). Build a 4-point 3D
// kd-tree and verify nearest-neighbor queries through the
// f64 surface.
//
// Points placed at the unit-cube corners (0,0,0), (1,0,0),
// (0,1,0), (0,0,1). Query at (0.9, 0.1, 0.1) — nearest is
// the (1,0,0) corner = index 1.
//
// EXPECT: build success, runtime exit 0, output "OK kdt_f64".

import "stdlib/rods/kdt.nr"

fn main() -> i32 {
    let h: i64 = kdt_new(4);

    let i0: i64 = kdt_insert_f64(h, 0.0, 0.0, 0.0);
    let i1: i64 = kdt_insert_f64(h, 1.0, 0.0, 0.0);
    let i2: i64 = kdt_insert_f64(h, 0.0, 1.0, 0.0);
    let i3: i64 = kdt_insert_f64(h, 0.0, 0.0, 1.0);

    // The runtime returns 0-indexed point ids.
    if i0 != 0 { print("FAIL i0"); return 1; };
    if i1 != 1 { print("FAIL i1"); return 1; };
    if i2 != 2 { print("FAIL i2"); return 1; };
    if i3 != 3 { print("FAIL i3"); return 1; };

    let n: i64 = kdt_build(h);
    if n != 4 { print("FAIL build count"); return 1; };

    // Query near the (1,0,0) corner.
    let nn: i64 = kdt_nearest_f64(h, 0.9, 0.1, 0.1);
    if nn != 1 { print("FAIL nearest(0.9,0.1,0.1)"); return 1; };

    // Query near the origin.
    let nn0: i64 = kdt_nearest_f64(h, 0.05, 0.05, 0.05);
    if nn0 != 0 { print("FAIL nearest(0.05,0.05,0.05)"); return 1; };

    // Query near (0,1,0).
    let nn2: i64 = kdt_nearest_f64(h, 0.1, 0.9, 0.1);
    if nn2 != 2 { print("FAIL nearest(0.1,0.9,0.1)"); return 1; };

    kdt_free(h);

    print("OK kdt_f64");
    0
}
