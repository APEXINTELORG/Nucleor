// repro_v52_str_eq_pointer_guard.nr
//
// v0.4.52 NUC-FEEDBACK silent-miscompute guard for `str == str`
// and `str != str`. Pre-fix the binop did pointer comparison,
// returning FALSE for two equal-bytes string literals at different
// addresses. Adopters writing the canonical Rust idiom got a quiet
// wrong result.
//
// v0.4.52 emits TYP-011 with a hint pointing at `str_eq(a, b) == 1`
// (or `== 0` for !=) for value comparison.

fn main() -> i64 {
    let a: str = "hello";
    let b: str = "hello";
    if a == b {                        // TYP-011 expected (op 30)
        println!("equal");
    } else {
        println!("not equal");
    };
    if a != b {                        // TYP-011 expected (op 31)
        println!("notnoteq");
    };
    return 0;
}
