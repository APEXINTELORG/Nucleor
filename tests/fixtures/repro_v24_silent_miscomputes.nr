// Repros all 3 silent miscomputes that v0.4.24 closes.
fn main() -> i64 {
    // Bug 1: 1.0f32 in Vec<f32>
    let mut v: Vec<f32> = Vec::new();
    v.push(1.0f32);
    v.push(2.5f32);
    let g0: f32 = vec_get(v, 0);
    let g1: f32 = vec_get(v, 1);
    if f32_to_bits(g0) == 1065353216 { print("PASS f32_lit_1.0"); } else { print("FAIL f32_lit_1.0"); };
    if f32_to_bits(g1) == 1075838976 { print("PASS f32_lit_2.5"); } else { print("FAIL f32_lit_2.5"); };

    // Bug 2: -1.5f32 negation
    let neg: f32 = -1.5f32;
    if f32_to_bits(neg) == 3217031168 { print("PASS f32_neg_-1.5"); } else { print("FAIL f32_neg_-1.5"); };

    // Bug 3: {:.3} on f64 prints VALUE not bit pattern
    let f: f64 = 3.14159;
    println!("spec_check {:.3}", f);  // verify gate greps for "spec_check 3.14159"

    return 0;
}
