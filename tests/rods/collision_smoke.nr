// rods/collision — verify rod wrapper compiles + links (v0.2.178 ship).
// Two unit spheres at (0,0,0) and (1.5,0,0): no overlap (dist 1.5 > 1+1).
// Two unit spheres at (0,0,0) and (1.0,0,0): overlap (dist 1.0 < 1+1).
import "stdlib/rods/collision.nr"

// v0.3.211: removed local f64_to_bits -- builtin in runtime helper table now bit-casts; local x as i64 body would now numeric-truncate.

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

    // CCD sphere-AABB (v0.2.201): linkage smoke — just call the
    // function with a swept-through case. Bit-cast comparison
    // against the -1.0 sentinel is unreliable in pure Nucleor
    // because `0.0 - 1.0` would do integer arithmetic on the
    // bit patterns; the C-side correctness is covered by the
    // direct C unit test (`target/_test_ccd.c`).
    let _ccd_sa: i64 = coll_ccd_sphere_aabb(
        f64_to_bits(0.0 - 5.0), f64_to_bits(0.5), f64_to_bits(0.5),
        f64_to_bits(5.0), f64_to_bits(0.5), f64_to_bits(0.5),
        f64_to_bits(0.1),
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0));

    // CCD capsule-capsule (v0.2.201): linkage smoke.
    let _ccd_cc: i64 = coll_ccd_capsule_capsule(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.1),
        f64_to_bits(10.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(10.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(11.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(11.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.1));

    if fail == 0 { print("OK collision_smoke"); };
    return fail;
}
