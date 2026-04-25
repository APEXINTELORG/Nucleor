// v0.3.15 RFC-0028 phase 3 — format3_ssf combo. Two strs +
// f64 (e.g. "{} {}: {}", category, key, measurement). Useful
// for metrics, CSV-ish output, and instrumented log lines.
// Same wiring shape as the prior format3_* additions.

fn main() -> i32 {
    let val: f64 = 3.14;
    let s1: str = format3_ssf("{} {}: {}", "metric", "pi", val);
    print(s1);

    let temp: f64 = 22.5;
    let s2: str = format3_ssf("{} {}: {}", "sensor", "temp_c", temp);
    print(s2);

    print("OK format3_ssf");
    return 0;
}
