// RFC-0042 auto-drop first cut.
// The runtime-visible assertion is "does not crash": if auto-drop
// double-frees after an explicit vec_free, this fixture tends to fault.

#[auto_drop]
fn local_drop(x: i64) -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(x);
    v.push(2);
    return v.len();
}

#[auto_drop]
fn rebinding_drop() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(1);
    v = Vec::new();
    v.push(2);
    return v.len();
}

#[auto_drop]
fn manual_free_once() -> i64 {
    let v: Vec<i64> = Vec::new();
    vec_free(v);
    return 7;
}

fn main() -> i32 {
    let a: i64 = local_drop(3);
    let b: i64 = rebinding_drop();
    let c: i64 = manual_free_once();
    if a != 2 { return 1; };
    if b != 1 { return 2; };
    if c != 7 { return 3; };
    return 0;
}
