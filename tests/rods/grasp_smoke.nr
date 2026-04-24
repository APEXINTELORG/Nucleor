// rods/grasp — verify rod wrapper compiles + links (v0.2.216 ship).
// Two contact points along the x-axis with opposing normals: a
// perfect antipodal grasp (score = +1, force closure under any μ).
import "stdlib/rods/grasp.nr"

fn f64_to_bits(x: f64) -> i64 { return x as i64; }

fn main() -> i64 {
    let mut fail: i64 = 0;

    // Perfect antipodal: c0 at (-1, 0, 0) with normal -x; c1 at (1, 0, 0)
    // with normal +x. Grip line is +x; both contacts' surface normals
    // are aligned with the grip-line for force closure.
    let _s: i64 = grasp_antipodal_score(
        f64_to_bits(0.0 - 1.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(0.0 - 1.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0),       f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0),       f64_to_bits(0.0), f64_to_bits(0.0));

    // Force closure under μ = 0.3.
    let fc: i64 = grasp_force_closure(
        f64_to_bits(0.0 - 1.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(0.0 - 1.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0),       f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0),       f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(0.3));
    if fc != 1 { fail = fail + 1; print("FAIL force closure on antipodal grasp"); };

    // Approach alignment: +z surface normal, -z approach → score +1.
    let _aa: i64 = grasp_approach_alignment(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(1.0),
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0 - 1.0));

    if fail == 0 { print("OK grasp_smoke"); };
    return fail;
}
