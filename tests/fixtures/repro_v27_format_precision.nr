// v0.4.27 RFC-0028 phase 5 — precision spec {:.N} for floats.
fn main() -> i64 {
    let pi: f64 = 3.14159265;
    println!("{:.3}", pi);    // expect 3.142
    println!("{:.0}", pi);    // expect 3
    println!("{:.6}", pi);    // expect 3.141593
    let e: f64 = 2.71828;
    println!("{:.2}", e);     // expect 2.72
    let neg: f64 = -1.5;
    println!("{:.4}", neg);   // expect -1.5000
    return 0;
}
