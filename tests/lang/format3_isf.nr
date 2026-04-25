// v0.3.17 RFC-0028 phase 3 — format3_isf combo. i64 + str +
// f64. Common shape for profile/step output where you tag a
// numbered step with a stage name and a measured time.

fn main() -> i32 {
    let t1: f64 = 0.42;
    let s1: str = format3_isf("Step {} ({}): {}", 1, "warmup", t1);
    print(s1);

    let t2: f64 = 12.5;
    let s2: str = format3_isf("Step {} ({}): {} ms", 2, "compile", t2);
    print(s2);

    print("OK format3_isf");
    return 0;
}
