// Test integer math intrinsics: abs, min, max, clamp
// Expected output: 5\n5\n3\n7\n5

fn main() -> i32 {
    // abs
    let a: i32 = abs(-5);
    print_int(a);

    let b: i32 = abs(5);
    print_int(b);

    // min
    let c: i32 = min(3, 7);
    print_int(c);

    // max
    let d: i32 = max(3, 7);
    print_int(d);

    // clamp
    let e: i32 = clamp(10, 0, 5);
    print_int(e);

    0
}
