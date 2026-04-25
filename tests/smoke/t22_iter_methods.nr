// T2.2 (v0.2.348) smoke: Vec iterator method dispatch.
// `v.map(f)` / `v.filter(p)` / `v.fold(init, f)` / `v.sum()` /
// `v.min()` / `v.max()` etc. dispatch to the typed
// `vec_*_i64` runtime helpers in nucleor_llvm_rt.c.
//
// Function-pointer args use named fns (e.g. pass `dbl` by name).
// Closure literals (`|x| x * 2`) ship in T2.3.

fn dbl(x: i64) -> i64 { return x * 2; }
fn even(x: i64) -> i64 { if x - (x / 2) * 2 == 0 { return 1; }; return 0; }
fn add(a: i64, b: i64) -> i64 { return a + b; }

#[test]
fn test_map() {
    let mut v: Vec<i32> = Vec::new();
    v.push(1); v.push(2); v.push(3);
    let doubled: Vec<i32> = v.map(dbl);
    assert_eq(vec_len(doubled), 3);
    assert_eq(vec_get(doubled, 0), 2);
    assert_eq(vec_get(doubled, 1), 4);
    assert_eq(vec_get(doubled, 2), 6);
}

#[test]
fn test_filter() {
    let mut v: Vec<i32> = Vec::new();
    v.push(1); v.push(2); v.push(3); v.push(4);
    let evens: Vec<i32> = v.filter(even);
    assert_eq(vec_len(evens), 2);
    assert_eq(vec_get(evens, 0), 2);
    assert_eq(vec_get(evens, 1), 4);
}

#[test]
fn test_fold_and_sum() {
    let mut v: Vec<i32> = Vec::new();
    v.push(10); v.push(20); v.push(30);
    assert_eq(v.sum(), 60);
    assert_eq(v.fold(0, add), 60);
    assert_eq(v.fold(100, add), 160);
}

#[test]
fn test_min_max() {
    let mut v: Vec<i32> = Vec::new();
    v.push(7); v.push(3); v.push(9); v.push(1);
    assert_eq(v.min(), 1);
    assert_eq(v.max(), 9);
}

#[test]
fn test_chain() {
    // map + filter + fold composes — the most common pipeline.
    let mut v: Vec<i32> = Vec::new();
    v.push(1); v.push(2); v.push(3); v.push(4); v.push(5);
    let pipeline_sum: i64 = v.map(dbl).filter(even).fold(0, add);
    // 1*2=2, 2*2=4, 3*2=6, 4*2=8, 5*2=10  → all even after doubling
    // sum = 2+4+6+8+10 = 30
    assert_eq(pipeline_sum, 30);
}
