// Lane 2 positive (G5-P-1): ptr_is_null intrinsic must compile
// and return 1 for 0 / 0 for non-zero. Pre-fix this fixture
// failed with TYP-005 because the function the FFI-G5
// diagnostic recommended as the remediation was undefined.
fn main() -> i32 {
    let zero: i64 = 0;
    let nonzero: i64 = 7;
    let r1: i64 = ptr_is_null(zero);
    let r2: i64 = ptr_is_null(nonzero);
    if r1 == 1 && r2 == 0 { print("OK ptr_is_null_intrinsic\n"); 0 } else { 1 }
}
