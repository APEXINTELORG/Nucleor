// p2_literals/lit_f32_suffix.nr — Phase 2: f32 suffix literal
// Float case — compare against constructed reference.

fn main() -> i32 {
    let a: f32 = 3.14f32;
    let ref: f32 = 3.14;
    if a != ref {
        print("FAIL: 3.14f32 mismatch\n");
        return 1;
    };
    print("OK lit_f32_suffix\n");
    return 0;
}
