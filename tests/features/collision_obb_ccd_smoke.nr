// helper1 ROBO-13 -- OBB-OBB SAT + translational CCD smoke.
//
// Locks fixed-orientation OBB overlap and swept center translation over
// [0, 1]. Angular CCD and convex mesh sweep remain separate follow-up
// work.

import "stdlib/rods/collision.nr"

fn close(a: f64, b: f64, eps: f64) -> i64 {
    let d: f64 = a - b;
    let ad: f64 = if d < 0.0 { 0.0 - d } else { d };
    if ad < eps { return 1; };
    return 0;
}

fn check_static_overlap() -> i64 {
    let r: i64 = coll_obb_obb(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.5), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0));
    if r != 1 { return 1; };
    return 0;
}

fn check_static_clear() -> i64 {
    let r: i64 = coll_obb_obb(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(3.1), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0));
    if r != 0 { return 2; };
    return 0;
}

fn check_sweep_hit() -> i64 {
    let t: f64 = f64_from_bits(coll_ccd_obb_obb(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(4.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(5.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(5.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0)));
    if close(t, 0.75, 0.000001) != 1 { return 4; };
    return 0;
}

fn check_sweep_initial_overlap() -> i64 {
    let t: f64 = f64_from_bits(coll_ccd_obb_obb(
        f64_to_bits(3.2), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(4.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(5.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(5.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0)));
    if close(t, 0.0, 0.000001) != 1 { return 8; };
    return 0;
}

fn check_sweep_clear() -> i64 {
    let t: f64 = f64_from_bits(coll_ccd_obb_obb(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(2.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(5.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(5.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0)));
    if close(t, 0.0 - 1.0, 0.000001) != 1 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_static_overlap();
    fails = fails + check_static_clear();
    fails = fails + check_sweep_hit();
    fails = fails + check_sweep_initial_overlap();
    fails = fails + check_sweep_clear();
    return fails;
}
