// v0.6.78 RFC V1.11: `&[T]` slice type as fn-param. Pre-fix the
// canonical Rust shape rejected with the wrong-class
// `error[NR020]: parse error at byte K: expected ';', got ']'`
// because the array-type parser only knew `[T; N]`. Now `[T]`
// (no length) resolves to `Vec<T>`, so `&[T]` resolves to
// `&Vec<T>` — which the type system already accepts. Slice ABI
// (length-tagged base+len) is the v1 V1.5 ship; this is a
// translation-fidelity surface bridge.
fn first(s: &[i64]) -> i64 {
    return vec_get(s, 0);
}

fn last(s: &[i64]) -> i64 {
    let n: i64 = vec_len(s);
    return vec_get(s, n - 1);
}

fn main() -> i32 {
    let v: Vec<i64> = [10, 20, 30, 40];
    print_int(first(&v) as i32);
    print_int(last(&v) as i32);
    return 0;
}
