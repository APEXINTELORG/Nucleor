// option.nr — Option type (Some/None) using Vec with tag
fn option_some(val: i64) -> Vec<i32> { let mut o: Vec<i32> = Vec::new(); o.push(1); o.push(val); return o; }
fn option_none() -> Vec<i32> { let mut o: Vec<i32> = Vec::new(); o.push(0); o.push(0); return o; }
fn option_is_some(o: Vec<i32>) -> i64 { return o.get(0); }
fn option_is_none(o: Vec<i32>) -> i64 { if o.get(0) == 0 { return 1; }; return 0; }
fn option_unwrap(o: Vec<i32>) -> i64 { if o.get(0) == 0 { print("ERROR: unwrap on None"); }; return o.get(1); }
fn option_unwrap_or(o: Vec<i32>, default: i64) -> i64 { if o.get(0) == 0 { return default; }; return o.get(1); }
