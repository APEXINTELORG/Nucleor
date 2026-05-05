// v0.8.225 stdlib/rods/grasp.nr first test coverage.
//
// Grasp quality metrics for a 2-finger parallel-jaw gripper —
// antipodal score, Coulomb friction force-closure, approach
// alignment. Pre-v0.8.225: zero coverage on the standalone
// rod.
//
// Locks four textbook geometric invariants:
//
//   1. **Perfect antipodal grasp** — contacts at (-1,0,0) and
//      (1,0,0) with outward normals (-1,0,0) and (1,0,0).
//      Grip line is the x-axis; both normals align → score=+1.
//   2. **Tangential normals score 0** — same contacts but
//      normals (0,1,0) and (0,1,0) (both pointing +y) are
//      orthogonal to grip line → 0.
//   3. **Force closure with μ=1** for a perfect antipodal pair.
//   4. **Approach alignment head-on** — surface normal (0,0,1),
//      approach (0,0,-1) (antiparallel) → +1.
//
// Expected: rc=0.

import "stdlib/rods/grasp.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_perfect_antipodal() -> i64 {
    let s: i64 = grasp_antipodal_score(
        f64_to_bits(0.0 - 1.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(0.0 - 1.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0)
    );
    if close(s, f64_to_bits(1.0), 1e-6) != 1 { return 1; };
    return 0;
}

fn check_tangential_zero() -> i64 {
    let s: i64 = grasp_antipodal_score(
        f64_to_bits(0.0 - 1.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(0.0), f64_to_bits(1.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(0.0), f64_to_bits(1.0), f64_to_bits(0.0)
    );
    if close(s, f64_to_bits(0.0), 1e-6) != 1 { return 2; };
    return 0;
}

fn check_force_closure_perfect() -> i64 {
    let r: i64 = grasp_force_closure(
        f64_to_bits(0.0 - 1.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(0.0 - 1.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0)
    );
    if r != 1 { return 4; };
    return 0;
}

fn check_approach_alignment_head_on() -> i64 {
    let s: i64 = grasp_approach_alignment(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(1.0),
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0 - 1.0)
    );
    if close(s, f64_to_bits(1.0), 1e-6) != 1 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_perfect_antipodal();
    fails = fails + check_tangential_zero();
    fails = fails + check_force_closure_perfect();
    fails = fails + check_approach_alignment_head_on();
    return fails;
}
