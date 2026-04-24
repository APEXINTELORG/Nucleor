// rods/bvh — verify rod wrapper compiles + links (v0.2.184 ship).
// Build a 3-AABB BVH, query an overlap, enumerate self-pairs.
import "stdlib/rods/bvh.nr"

fn f64_to_bits(x: f64) -> i64 { return x as i64; }

fn main() -> i64 {
    let mut fail: i64 = 0;
    let bvh: i64 = bvh_new();

    // Three boxes: A at [0,1], B at [0.5,1.5] (overlaps A), C at [3,4] (alone).
    let _idx_a: i64 = bvh_add(bvh,
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0));
    let _idx_b: i64 = bvh_add(bvh,
        f64_to_bits(0.5), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.5), f64_to_bits(1.0), f64_to_bits(1.0));
    let _idx_c: i64 = bvh_add(bvh,
        f64_to_bits(3.0), f64_to_bits(3.0), f64_to_bits(3.0),
        f64_to_bits(4.0), f64_to_bits(4.0), f64_to_bits(4.0));

    bvh_build(bvh);

    // Query at [0, 1]: should hit A and B (not C).
    let n: i64 = bvh_query(bvh,
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0));
    if n != 2 { fail = fail + 1; print("FAIL query expected 2 hits"); };

    // Self-pair query: should find exactly the (A, B) pair.
    let p: i64 = bvh_self_pairs(bvh);
    if p != 1 { fail = fail + 1; print("FAIL self_pairs expected 1"); };

    bvh_free(bvh);
    if fail == 0 { print("OK bvh_smoke"); };
    return fail;
}
