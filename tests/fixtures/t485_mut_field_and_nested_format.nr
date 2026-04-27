// More aggressive hazard probes against v0.4.15.

pub struct GapReport { severity: i64, message: str }

// HAZARD 16: Method-style fn call on local with format
fn hz16_method_call_format() -> i64 {
    let s: str = "hello world";
    let n: i64 = str_len(s);
    let formatted: str = format!("len={}", n);
    if str_eq(formatted, "len=11") != 1 { return 1; };
    return 0;
}

// HAZARD 17: Mutating Vec via match arm
fn hz17_mut_vec_in_match() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    let opt: Option<i64> = Some(42);
    match opt {
        None => return 1,
        Some(x) => {
            vec_push(v, x);
            vec_push(v, x + 1);
        },
    };
    if vec_len(v) != 2 { return 1; };
    if vec_get(v, 0) != 42 { return 1; };
    if vec_get(v, 1) != 43 { return 1; };
    return 0;
}

// HAZARD 18: struct field mutation
pub struct Counter { mut value: i64 }
fn hz18_field_mutation() -> i64 {
    let mut c: Counter = Counter { value: 0 };
    c.value = 7;
    if c.value != 7 { return 1; };
    return 0;
}

// HAZARD 19: deeply nested format with calls
fn hz19_deep_nested() -> i64 {
    let a: str = "outer";
    let b: str = "inner";
    let s: str = format!("[{}]({})", a, format!("nested:{}", b));
    if str_eq(s, "[outer](nested:inner)") != 1 { return 1; };
    return 0;
}

// HAZARD 20: Empty Vec format
fn hz20_empty_vec_format() -> i64 {
    let v: Vec<i64> = Vec::new();
    let s: str = format!("len={}", vec_len(v));
    if str_eq(s, "len=0") != 1 { return 1; };
    return 0;
}

fn main() -> i64 {
    if hz16_method_call_format() != 0 { println!("FAIL hz16"); return 16; };
    if hz17_mut_vec_in_match() != 0 { println!("FAIL hz17"); return 17; };
    if hz18_field_mutation() != 0 { println!("FAIL hz18"); return 18; };
    if hz19_deep_nested() != 0 { println!("FAIL hz19"); return 19; };
    if hz20_empty_vec_format() != 0 { println!("FAIL hz20"); return 20; };
    println!("all clean");
    return 0;
}
