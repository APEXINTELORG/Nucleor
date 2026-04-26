// rods/voxel — verify rod wrapper compiles + links (v0.2.239 ship).
// Tiny grid, insert + query a couple of cells.
import "stdlib/rods/voxel.nr"

// v0.3.211: removed local f64_to_bits -- builtin in runtime helper table now bit-casts; local x as i64 body would now numeric-truncate.

fn main() -> i64 {
    let mut fail: i64 = 0;
    // 10×10×10 grid centered at origin, 0.1m resolution → 1m³ extent.
    let v: i64 = vox_new(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(0.1), 10, 10, 10);
    if v == 0 { print("FAIL vox_new"); return 1; };

    if vox_total_count(v) != 1000 {
        fail = fail + 1; print("FAIL vox_total_count");
    };
    if vox_occupied_count(v) != 0 {
        fail = fail + 1; print("FAIL initial occupied count");
    };

    if vox_insert(v, f64_to_bits(0.3), f64_to_bits(0.2), f64_to_bits(0.1), 1) != 0 {
        fail = fail + 1; print("FAIL insert occupied");
    };
    if vox_query(v, f64_to_bits(0.3), f64_to_bits(0.2), f64_to_bits(0.1)) != 2 {
        fail = fail + 1; print("FAIL query occupied != 2");
    };
    if vox_occupied_count(v) != 1 {
        fail = fail + 1; print("FAIL occupied count after insert");
    };
    // Insert a free cell.
    if vox_insert(v, f64_to_bits(0.4), f64_to_bits(0.4), f64_to_bits(0.4), 0) != 0 {
        fail = fail + 1; print("FAIL insert free");
    };
    if vox_query(v, f64_to_bits(0.4), f64_to_bits(0.4), f64_to_bits(0.4)) != 1 {
        fail = fail + 1; print("FAIL query free != 1");
    };
    // Out-of-range insert.
    if vox_insert(v, f64_to_bits(5.0), f64_to_bits(0.0), f64_to_bits(0.0), 1) != 0 - 1 {
        fail = fail + 1; print("FAIL out-of-range insert did not return -1");
    };

    vox_free(v);
    if fail == 0 { print("OK voxel_smoke"); };
    return fail;
}
