// Test f64 math intrinsics: sqrt, sin, cos, pow, floor, ceil, conversions
// Expected output: 4\n1\n8\n3\n4

fn main() -> i32 {
    // sqrt(16.0) = 4.0 -> 4
    let a: f64 = sqrt(16.0);
    let ai: i32 = f64_to_i32(a);
    print_int(ai);

    // cos(0.0) = 1.0 -> 1
    let b: f64 = cos(0.0);
    let bi: i32 = f64_to_i32(b);
    print_int(bi);

    // pow(2.0, 3.0) = 8.0 -> 8
    let c: f64 = pow(2.0, 3.0);
    let ci: i32 = f64_to_i32(c);
    print_int(ci);

    // floor(3.7) = 3.0 -> 3
    let d: f64 = floor(3.7);
    let di: i32 = f64_to_i32(d);
    print_int(di);

    // ceil(3.2) = 4.0 -> 4
    let e: f64 = ceil(3.2);
    let ei: i32 = f64_to_i32(e);
    print_int(ei);

    0
}
