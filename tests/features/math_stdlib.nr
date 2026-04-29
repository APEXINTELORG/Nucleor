// Phase 6d: Stdlib math functions via libm

fn main() -> i32 {
    // sqrt(9.0) = 3.0
    let s = sqrt(9.0);
    print_int(f64_to_i32(s));

    // sin(0.0) = 0.0
    let sn = sin(0.0);
    print_int(f64_to_i32(sn));

    // cos(0.0) = 1.0
    let cs = cos(0.0);
    print_int(f64_to_i32(cs));

    // exp(0.0) = 1.0
    let e = exp(0.0);
    print_int(f64_to_i32(e));

    // log(1.0) = 0.0
    let lg = log(1.0);
    print_int(f64_to_i32(lg));

    // pow(2.0, 10.0) = 1024.0
    let p = pow(2.0, 10.0);
    print_int(f64_to_i32(p));

    // floor(3.7) = 3.0
    let fl = floor(3.7);
    print_int(f64_to_i32(fl));

    // ceil(3.2) = 4.0
    let cl = ceil(3.2);
    print_int(f64_to_i32(cl));

    0
}
