fn main() -> i32 {
    // Test extended math operations
    let x: f64 = 2.0;

    let s: f64 = sqrt(x);
    print_f64(s);

    let e: f64 = exp(1.0);
    print_f64(e);

    let l: f64 = log(e);
    print_f64(l);

    let p: f64 = pow(2.0, 10.0);
    print_f64(p);

    let fl: f64 = floor(2.7);
    print_f64(fl);

    let cl: f64 = ceil(2.3);
    print_f64(cl);

    let rd: f64 = round(2.5);
    print_f64(rd);

    // Integer ops
    let a: i32 = abs(-5);
    print_int(a);

    let mn: i32 = min(3, 7);
    print_int(mn);

    let mx: i32 = max(3, 7);
    print_int(mx);

    let cl2: i32 = clamp(15, 0, 10);
    print_int(cl2);

    0
}
