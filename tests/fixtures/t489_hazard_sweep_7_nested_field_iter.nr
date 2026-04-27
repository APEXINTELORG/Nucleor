// Hazard sweep #7 — really obscure adopter patterns.

pub struct Inner { pub val: i64 }
pub struct Outer { pub inner: Inner, pub name: str }

// HAZARD 36: nested struct field access (a.b.c)
fn hz36_nested_field() -> i64 {
    let o: Outer = Outer { inner: Inner { val: 99 }, name: "x" };
    if o.inner.val != 99 { return 1; };
    let s: str = format!("v={}", o.inner.val);
    if str_eq(s, "v=99") != 1 { return 1; };
    return 0;
}

// HAZARD 37: Strict arith should panic on i64 overflow when env enabled
// (not testable here without env; just verify no silent wrong answer for clean cases)
fn hz37_arith_safety() -> i64 {
    let a: i64 = 1000000;
    let b: i64 = 1000000;
    let c: i64 = a * b;
    if c != 1000000000000 { return 1; };
    return 0;
}

// HAZARD 38: Vec<i64> sum via while
fn hz38_vec_sum() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    vec_push(v, 1); vec_push(v, 2); vec_push(v, 3); vec_push(v, 4); vec_push(v, 5);
    let mut sum: i64 = 0;
    let mut i: i64 = 0;
    while i < vec_len(v) {
        sum = sum + vec_get(v, i);
        i = i + 1;
    };
    if sum != 15 { return 1; };
    return 0;
}

// HAZARD 39: HashMap iteration via keys
fn hz39_hashmap_iter() -> i64 {
    let h: HashMap<str, i64> = HashMap::new();
    hashmap_insert(h, "a", 1);
    hashmap_insert(h, "b", 2);
    hashmap_insert(h, "c", 3);
    let keys: Vec<str> = hashmap_keys(h);
    if vec_len(keys) != 3 { return 1; };
    let mut total: i64 = 0;
    let mut i: i64 = 0;
    while i < vec_len(keys) {
        let k: str = vec_get(keys, i);
        total = total + hashmap_get(h, k);
        i = i + 1;
    };
    if total != 6 { return 1; };
    return 0;
}

// HAZARD 40: bool field via `if struct.flag`
pub struct Flag { pub on: bool, pub label: str }
fn hz40_bool_field_if() -> i64 {
    let f: Flag = Flag { on: true, label: "yes" };
    if f.on {
        let s: str = format!("{} is on", f.label);
        if str_eq(s, "yes is on") != 1 { return 1; };
        return 0;
    };
    return 1;
}

fn main() -> i64 {
    if hz36_nested_field() != 0 { println!("FAIL hz36"); return 36; };
    if hz37_arith_safety() != 0 { println!("FAIL hz37"); return 37; };
    if hz38_vec_sum() != 0 { println!("FAIL hz38"); return 38; };
    if hz39_hashmap_iter() != 0 { println!("FAIL hz39"); return 39; };
    if hz40_bool_field_if() != 0 { println!("FAIL hz40"); return 40; };
    println!("all clean");
    return 0;
}
