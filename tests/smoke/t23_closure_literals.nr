// T2.3 (v0.2.349) smoke: closure literals (no-capture).
// `|args| body` is recognized in argument position (after `(`,
// `,`, `=`, `=>`, `[`, `{`, `;`, or source start) and lifted
// into a synthesized top-level fn. The closure body extends
// until the first `,` or `)` at the same paren depth.
//
// Limitation: NO captures. The body must only reference its
// own arg names + global fns. T2.3b adds capture support via
// closure-object pairs (fn_ptr + env_ptr).

#[test]
fn test_map_with_closure() {
    let mut v: Vec<i32> = Vec::new();
    v.push(1); v.push(2); v.push(3);
    let squared: Vec<i32> = v.map(|x| x * x);
    assert_eq(vec_get(squared, 0), 1);
    assert_eq(vec_get(squared, 1), 4);
    assert_eq(vec_get(squared, 2), 9);
}

#[test]
fn test_filter_with_closure() {
    let mut v: Vec<i32> = Vec::new();
    v.push(1); v.push(2); v.push(3); v.push(4); v.push(5);
    let big: Vec<i32> = v.filter(|x| x);
    // pred returns the value itself; filter keeps non-zero → all 5
    assert_eq(vec_len(big), 5);
}

#[test]
fn test_fold_with_closure() {
    let mut v: Vec<i32> = Vec::new();
    v.push(2); v.push(3); v.push(4);
    let product: i64 = v.fold(1, |acc, x| acc * x);
    assert_eq(product, 24);
}

#[test]
fn test_chain_with_closures() {
    let mut v: Vec<i32> = Vec::new();
    v.push(1); v.push(2); v.push(3); v.push(4);
    // Pipeline: square each, keep odds (after squaring), sum.
    // 1²=1, 2²=4, 3²=9, 4²=16. Odd: 1, 9. Sum = 10.
    let result: i64 = v.map(|x| x * x).filter(|x| x - (x / 2) * 2).fold(0, |acc, x| acc + x);
    assert_eq(result, 10);
}
