// v0.4.38 RFC-0028 phase 5 — `{:e}` / `{:E}` scientific notation for f64.
fn main() -> i64 {
    let pi: f64 = 3.14159265;
    let big: f64 = 1234567.89;
    let tiny: f64 = 0.000001234;
    let neg: f64 = -1.5;

    println!("{:e}", pi);     // expect 3.141593e+00 (default 6 digits)
    println!("{:E}", pi);     // expect 3.141593E+00
    println!("{:e}", big);    // expect 1.234568e+06
    println!("{:e}", tiny);   // expect 1.234000e-06
    println!("{:e}", neg);    // expect -1.500000e+00

    // Precision spec
    println!("{:.3e}", pi);   // expect 3.142e+00
    println!("{:.0e}", pi);   // expect 3e+00
    println!("{:.3E}", pi);   // expect 3.142E+00

    return 0;
}
