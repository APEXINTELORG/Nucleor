// rods/collision — verify rod wrapper compiles + links (v0.2.178 ship).
// Two unit spheres at (0,0,0) and (1.5,0,0): no overlap (dist 1.5 > 1+1).
// Two unit spheres at (0,0,0) and (1.0,0,0): overlap (dist 1.0 < 1+1).
import "stdlib/rods/collision.nr"

fn f64_to_bits(x: f64) -> i64 { return x as i64; }

fn main() -> i64 {
    let mut fail: i64 = 0;

    // Spheres apart (centers 1.5m apart, sum-of-radii = 2.0).
    let no_hit: i64 = coll_sphere_sphere(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.5),
        f64_to_bits(1.5), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.5)
    );
    if no_hit != 0 { fail = fail + 1; print("FAIL spheres reported overlap"); };

    // Spheres overlapping (centers 1.0m apart, sum-of-radii = 2.0).
    let hit: i64 = coll_sphere_sphere(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(1.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(1.0)
    );
    if hit != 1 { fail = fail + 1; print("FAIL spheres reported no overlap"); };

    // AABBs touching at the corner (max == min along x-axis).
    let aabb_hit: i64 = coll_aabb_aabb(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(2.0), f64_to_bits(1.0), f64_to_bits(1.0)
    );
    if aabb_hit != 1 { fail = fail + 1; print("FAIL aabb-touching reported no overlap"); };

    // Sphere-AABB cross-pair (v0.2.195): sphere center inside AABB.
    let sa: i64 = coll_sphere_aabb(
        f64_to_bits(0.5), f64_to_bits(0.5), f64_to_bits(0.5), f64_to_bits(0.1),
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0));
    if sa != 1 { fail = fail + 1; print("FAIL sphere-AABB inside reported clear"); };

    // Sphere-AABB clear: sphere far away.
    let sa_clear: i64 = coll_sphere_aabb(
        f64_to_bits(5.0), f64_to_bits(5.0), f64_to_bits(5.0), f64_to_bits(0.1),
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0));
    if sa_clear != 0 { fail = fail + 1; print("FAIL sphere-AABB far reported overlap"); };

    if fail == 0 { print("OK collision_smoke"); };
    return fail;
}
