// RFC-0028 phase 4 (v0.2.158) — three more format combinations
// covering float-mixed and 3-float surfaces:
//   format2_fi(tmpl, f64, i64)  e.g. "ratio={}, count={}"
//   format2_if(tmpl, i64, f64)  e.g. "step={}, error={}"
//   format3_fff(tmpl, f64, f64, f64)  e.g. "({}, {}, {})" 3D vec

fn main() -> i64 {
    let mut fail: i64 = 0;
    let pi: f64 = 3.14;
    let two: f64 = 2.0;

    let s1: str = format2_fi("ratio={}, count={}", pi, 5);
    if str_eq(s1, "ratio=3.14, count=5") == 0 { fail = fail + 1; print("FAIL format2_fi"); print(s1); };

    let s2: str = format2_if("step={}, error={}", 42, two);
    if str_eq(s2, "step=42, error=2") == 0 { fail = fail + 1; print("FAIL format2_if"); print(s2); };

    let s3: str = format3_fff("({}, {}, {})", pi, two, pi);
    if str_eq(s3, "(3.14, 2, 3.14)") == 0 { fail = fail + 1; print("FAIL format3_fff"); print(s3); };

    if fail == 0 { print("OK format_mixed_combos"); };
    return fail;
}
