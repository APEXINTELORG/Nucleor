// rods/sgrid — verify rod wrapper compiles + links (v0.2.245 ship).
// Build a small grid, insert several points, query nearest.
import "stdlib/rods/sgrid.nr"

fn f64_to_bits(x: f64) -> i64 { return x as i64; }

fn main() -> i64 {
    let mut fail: i64 = 0;
    let g: i64 = sgrid_new(f64_to_bits(0.5), 16);
    if g == 0 { print("FAIL sgrid_new"); return 1; };

    let _i0: i64 = sgrid_insert(g, f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0));
    let _i1: i64 = sgrid_insert(g, f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0));
    let _i2: i64 = sgrid_insert(g, f64_to_bits(2.0), f64_to_bits(0.0), f64_to_bits(0.0));
    if sgrid_count(g) != 3 {
        fail = fail + 1; print("FAIL sgrid_count");
    };

    // Query at (1.1, 0, 0) should return index 1 (point at (1, 0, 0)).
    let nn: i64 = sgrid_nearest(g, f64_to_bits(1.1), f64_to_bits(0.0), f64_to_bits(0.0));
    if nn != 1 {
        fail = fail + 1; print("FAIL nearest neighbor");
    };

    sgrid_free(g);
    if fail == 0 { print("OK sgrid_smoke"); };
    return fail;
}
