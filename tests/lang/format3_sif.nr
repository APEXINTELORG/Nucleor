// v0.3.16 RFC-0028 phase 3 — format3_sif combo. Str + i64 +
// f64. Common shape for benchmark/aggregation output where
// you need a category label, an item count, and a measured
// average.

fn main() -> i32 {
    let avg: f64 = 0.42;
    let s1: str = format3_sif("{} ({} samples): {}", "iter_ms", 100, avg);
    print(s1);

    let mean: f64 = 1.5;
    let s2: str = format3_sif("category={}, n={}, mean={}", "fast", 4, mean);
    print(s2);

    print("OK format3_sif");
    return 0;
}
