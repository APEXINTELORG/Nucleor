// EXPECT: error[TYP-027] type inference failed
//
// E3 / T-4 strict-inference sister fixture for
// tests/features/t4_empty_type_audit_lock.nr. Default-off mode keeps
// the historical canary compiling; NUC_STRICT_INFERENCE=1 rejects the
// empty-type sentinel from vec_get instead of accepting it as bool.

fn main() -> i64 {
    let mut xs: Vec<i64> = Vec::new();
    xs.push(1);
    let first: bool = vec_get(&xs, 0);
    if first { return 1; };
    return 0;
}
