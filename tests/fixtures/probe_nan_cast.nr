// Probe: NaN cast to int returns 0 (Rust as semantic), not UB
fn main() -> i64 {
    // NaN constructed as 0.0 / 0.0
    let zero: f64 = 0.0;
    let nan: f64 = zero / zero;
    let i: i64 = nan as i64;
    println!("{}", i);   // expect 0
    return 0;
}
