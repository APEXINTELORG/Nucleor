import "stdlib/rods/ml/shape_core.nr"

// ml_shape_core_smoke — round-trips shape2 construction + field reads
// from stdlib/rods/ml/shape_core.nr.

fn main() -> i32 {
    let mut fail: i64 = 0;

    let s: Shape2 = shape2(3, 5);
    if s.rows != 3 { print("FAIL shape2 rows"); fail = fail + 1; };
    if s.cols != 5 { print("FAIL shape2 cols"); fail = fail + 1; };

    let z: Shape2 = shape2(0, 0);
    if z.rows != 0 { print("FAIL shape2 zero rows"); fail = fail + 1; };
    if z.cols != 0 { print("FAIL shape2 zero cols"); fail = fail + 1; };

    let big: Shape2 = shape2(1024, 4096);
    if big.rows != 1024 { print("FAIL shape2 big rows"); fail = fail + 1; };
    if big.cols != 4096 { print("FAIL shape2 big cols"); fail = fail + 1; };

    if fail == 0 {
        print("OK ml_shape_core_smoke");
        return 0;
    };
    print("FAIL ml_shape_core_smoke");
    return 1;
}
