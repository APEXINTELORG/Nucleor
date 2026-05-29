// v0.8.236 stdlib/rods/cam.nr first test coverage.
//
// Pinhole camera with Brown-Conrady distortion. Pre-v0.8.236:
// zero coverage on the standalone rod.
//
// Locks four lifecycle invariants. Project / unproject / distort
// /set_pose all use raw double-array pointers; deferred to
// dedicated CV ships.
//
//   1. cam_new returns valid handle — non-zero for reasonable
//      intrinsics.
//   2. set_distortion does not crash — zero distortion (k1=
//      k2=k3=p1=p2=0) is the no-op identity case.
//   3. set_distortion with non-zero coeffs does not crash —
//      typical Brown-Conrady values.
//   4. cam_free does not crash on a freshly constructed
//      handle.
//
// Heavier tests (project / unproject round-trip) require raw
// double[] for input/output points; those land in dedicated
// computer-vision ships.
//
// Expected: rc=0.

import "stdlib/rods/cam.nr"

fn check_new_valid() -> i64 {
    let h: i64 = cam_new(
        f64_to_bits(500.0), f64_to_bits(500.0),
        f64_to_bits(320.0), f64_to_bits(240.0)
    );
    if h == 0 { return 1; };
    cam_free(h);
    return 0;
}

fn check_set_distortion_zero() -> i64 {
    let h: i64 = cam_new(
        f64_to_bits(500.0), f64_to_bits(500.0),
        f64_to_bits(320.0), f64_to_bits(240.0)
    );
    cam_set_distortion(h,
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(0.0), f64_to_bits(0.0)
    );
    cam_free(h);
    return 0;
}

fn check_set_distortion_nonzero() -> i64 {
    let h: i64 = cam_new(
        f64_to_bits(500.0), f64_to_bits(500.0),
        f64_to_bits(320.0), f64_to_bits(240.0)
    );
    cam_set_distortion(h,
        f64_to_bits(0.0 - 0.2), f64_to_bits(0.05), f64_to_bits(0.001),
        f64_to_bits(0.001), f64_to_bits(0.0 - 0.001)
    );
    cam_free(h);
    return 0;
}

fn check_free_non_crashing() -> i64 {
    let h: i64 = cam_new(
        f64_to_bits(100.0), f64_to_bits(100.0),
        f64_to_bits(50.0), f64_to_bits(50.0)
    );
    cam_free(h);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_new_valid();
    fails = fails + check_set_distortion_zero();
    fails = fails + check_set_distortion_nonzero();
    fails = fails + check_free_non_crashing();
    return fails;
}
