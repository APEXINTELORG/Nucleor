// T3.38 (v0.3.63) — regression test for the fixed-array-
// of-struct field-access codegen bug fixed in v0.3.63.
//
// Pre-v0.3.63: `arr[0].x` where arr: [V3; 2] failed
// compilation with `ERROR: cannot resolve field access type
// for .x`. Same bug class as v0.3.59 (Vec<struct> field
// access) but for fixed-size arrays. v0.3.59 added the
// kind==10 branch to expr_struct_type for `Vec<T>` only;
// v0.3.63 mirrors v0.3.62's `[T; N]` extension into
// expr_struct_type.
//
// Production-relevant: SE(3) pose batch as `[Pose; N]`,
// trajectory waypoints, IMU sample windows.
//
// Verify gate (T3.38) asserts the field access compiles
// AND produces correct values.

#[repr(C)]
struct V { x: f64, y: f64 }

fn main() -> i32 {
    let arr: [V; 2] = [V { x: 1.0, y: 2.0 }, V { x: 3.0, y: 4.0 }];

    let r1: f64 = arr[0].x;          // 1.0
    print_f64(r1);

    let r2: f64 = arr[0].x + arr[1].y;   // 5.0
    print_f64(r2);

    let r3: f64 = arr[1].x * arr[0].y;   // 6.0
    print_f64(r3);

    0
}
