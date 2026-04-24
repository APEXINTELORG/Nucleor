// rods/octree — verify rod wrapper compiles + links (v0.2.226 ship).
// Build a small octree, insert two opposing-octant points (one
// occupied, one free), query both back, verify node count grew.
import "stdlib/rods/octree.nr"

fn f64_to_bits(x: f64) -> i64 { return x as i64; }

fn main() -> i64 {
    let mut fail: i64 = 0;
    // Octree spans [-1, 1]³, max depth 4 → leaf size = 2/16 = 0.125 m.
    let oct: i64 = oct_new(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), 4);
    if oct == 0 { print("FAIL oct_new"); return 1; };

    // Insert occupied point at (0.5, 0.5, 0.5).
    if oct_insert(oct, f64_to_bits(0.5), f64_to_bits(0.5), f64_to_bits(0.5), 1) != 0 {
        fail = fail + 1; print("FAIL oct_insert occupied");
    };
    // Query — should be 2 (occupied).
    if oct_query(oct, f64_to_bits(0.5), f64_to_bits(0.5), f64_to_bits(0.5)) != 2 {
        fail = fail + 1; print("FAIL oct_query occupied");
    };

    // Insert free point at (0.7, 0.3, 0.1) — different leaf from
    // the occupied one. (Note: pure-Nucleor smoke can't easily
    // synthesize negative literals without runtime helpers; the
    // direct C test covers negative-coordinate inserts.)
    if oct_insert(oct, f64_to_bits(0.7), f64_to_bits(0.3),
                  f64_to_bits(0.1), 0) != 0 {
        fail = fail + 1; print("FAIL oct_insert free");
    };
    if oct_query(oct, f64_to_bits(0.7), f64_to_bits(0.3),
                 f64_to_bits(0.1)) != 1 {
        fail = fail + 1; print("FAIL oct_query free");
    };

    // Out-of-range insert returns -1.
    if oct_insert(oct, f64_to_bits(5.0), f64_to_bits(0.0), f64_to_bits(0.0), 1) != 0 - 1 {
        fail = fail + 1; print("FAIL out-of-range insert did not return -1");
    };

    if oct_node_count(oct) <= 1 {
        fail = fail + 1; print("FAIL node count did not grow after inserts");
    };

    oct_free(oct);
    if fail == 0 { print("OK octree_smoke"); };
    return fail;
}
