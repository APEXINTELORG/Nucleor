// T2.4 (v0.2.350) smoke: trait object 2-cell handle helpers.
// Manual dispatch pattern: a Box<dyn Trait> is represented as
// an i64 handle to a 2-cell allocation [type_id, data_ptr].
// Compiler-generated auto-dispatch sugar (`box.method(args)`)
// arrives in T2.4b; today users build the dispatcher manually
// via the runtime helpers `dyn_box_make / type / data / free`.

fn type_id_a() -> i64 { return 11; }
fn type_id_b() -> i64 { return 22; }

fn impl_a_double(data: i64) -> i64 { return data * 2; }
fn impl_b_negate(data: i64) -> i64 { return 0 - data; }

fn dispatch_op(box: i64) -> i64 {
    let tid: i64 = dyn_box_type(box);
    let data: i64 = dyn_box_data(box);
    if tid == 11 { return impl_a_double(data); };
    if tid == 22 { return impl_b_negate(data); };
    return 0 - 999;
}

#[test]
fn test_dyn_box_make_type_data() {
    let box: i64 = dyn_box_make(11, 42);
    let t: i64 = dyn_box_type(box);
    let d: i64 = dyn_box_data(box);
    dyn_box_free(box);
    assert_eq(t, 11);
    assert_eq(d, 42);
}

#[test]
fn test_dyn_box_dispatch_a() {
    let box: i64 = dyn_box_make(type_id_a(), 7);
    let r: i64 = dispatch_op(box);
    dyn_box_free(box);
    assert_eq(r, 14);
}

#[test]
fn test_dyn_box_dispatch_b() {
    let box: i64 = dyn_box_make(type_id_b(), 7);
    let r: i64 = dispatch_op(box);
    dyn_box_free(box);
    assert_eq(r, 0 - 7);
}

#[test]
fn test_dyn_box_polymorphic_collection() {
    // Vec<i32> of mixed-type boxes — the canonical trait-object use case.
    let mut col: Vec<i32> = Vec::new();
    col.push(dyn_box_make(11, 5));
    col.push(dyn_box_make(22, 5));
    col.push(dyn_box_make(11, 10));
    let mut total: i64 = 0;
    let n: i64 = vec_len(col);
    let mut i: i64 = 0;
    while i < n {
        let box: i64 = vec_get(col, i);
        total = total + dispatch_op(box);
        dyn_box_free(box);
        i = i + 1;
    };
    // 5*2 + (-5) + 10*2 = 10 - 5 + 20 = 25
    assert_eq(total, 25);
}

#[test]
fn test_dyn_box_unknown_tag_returns_default() {
    let box: i64 = dyn_box_make(999, 42);
    let r: i64 = dispatch_op(box);
    dyn_box_free(box);
    assert_eq(r, 0 - 999);
}
