// result.nr — Result type (Ok/Err) using Vec with tag
fn result_ok(val: i64) -> Vec<i32> { let mut r: Vec<i32> = Vec::new(); r.push(1); r.push(val); return r; }
fn result_err(val: i64) -> Vec<i32> { let mut r: Vec<i32> = Vec::new(); r.push(0); r.push(val); return r; }
fn result_is_ok(r: Vec<i32>) -> i64 { return r.get(0); }
fn result_is_err(r: Vec<i32>) -> i64 { if r.get(0) == 0 { return 1; }; return 0; }
fn result_unwrap(r: Vec<i32>) -> i64 { if r.get(0) == 0 { print("ERROR: unwrap on Err"); }; return r.get(1); }
fn result_unwrap_or(r: Vec<i32>, default: i64) -> i64 { if r.get(0) == 0 { return default; }; return r.get(1); }
