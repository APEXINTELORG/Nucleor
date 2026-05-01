// stdlib/rods/linalg — `*_f64` ergonomic wrappers.
//
// v0.4.262: continues the units (v0.4.260) + kinematics
// (v0.4.261) pattern. Adopters writing dense linear-algebra
// code now use f64-typed get/set/scale/norm/trace/det/rank.
// The bits-ABI fns remain for callers that already paid
// the f64_to_bits/from_bits cost.
//
// EXPECT: build success, runtime exit 0, output "OK linalg_f64".

import "stdlib/rods/linalg.nr"

fn main() -> i32 {
    // 2x2 identity scaled by 3:
    //   [3 0]
    //   [0 3]
    let i2: i64 = linalg_eye(2);
    let m: i64 = linalg_scale_f64(i2, 3.0);

    // Read back via _f64 getter.
    if (linalg_get_f64(m, 0, 0) as i32) != 3 { print("FAIL get(0,0)"); return 1; };
    if (linalg_get_f64(m, 1, 1) as i32) != 3 { print("FAIL get(1,1)"); return 1; };
    if (linalg_get_f64(m, 0, 1) as i32) != 0 { print("FAIL get(0,1)"); return 1; };

    // Trace: 3 + 3 = 6.
    let tr: f64 = linalg_trace_f64(m);
    if (tr as i32) != 6 { print("FAIL trace"); return 1; };

    // Determinant: 3 * 3 = 9.
    let det: f64 = linalg_det_f64(m);
    if (det as i32) != 9 { print("FAIL det"); return 1; };

    // Rank: full-rank 2x2 = 2 (with default-ish tol 1e-9).
    let r: i64 = linalg_rank_f64(m, 0.000000001);
    if r != 2 { print("FAIL rank"); return 1; };

    linalg_free(i2);
    linalg_free(m);

    // Mutate via _f64 setter; round-trip.
    let a: i64 = linalg_new(2, 2);
    linalg_set_f64(a, 0, 0, 1.0);
    linalg_set_f64(a, 0, 1, 2.0);
    linalg_set_f64(a, 1, 0, 3.0);
    linalg_set_f64(a, 1, 1, 4.0);

    if (linalg_get_f64(a, 0, 0) as i32) != 1 { print("FAIL set/get(0,0)"); return 1; };
    if (linalg_get_f64(a, 0, 1) as i32) != 2 { print("FAIL set/get(0,1)"); return 1; };
    if (linalg_get_f64(a, 1, 0) as i32) != 3 { print("FAIL set/get(1,0)"); return 1; };
    if (linalg_get_f64(a, 1, 1) as i32) != 4 { print("FAIL set/get(1,1)"); return 1; };

    // det(a) = 1*4 - 2*3 = -2.
    let det_a: f64 = linalg_det_f64(a);
    if (det_a as i32) != (0 - 2) { print("FAIL det a"); return 1; };

    linalg_free(a);

    print("OK linalg_f64");
    0
}
