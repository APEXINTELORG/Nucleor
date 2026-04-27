// Hazard sweep #4 against v0.4.16.

pub struct Person { pub name: str, pub age: i64 }

// HAZARD 21: format!() on a fn returning a struct, then field access
fn make_person() -> Person { return Person { name: "Alice", age: 30 }; }
fn hz21_fn_struct_field() -> i64 {
    let p: Person = make_person();
    let s: str = format!("{} is {}", p.name, p.age);
    if str_eq(s, "Alice is 30") != 1 { return 1; };
    return 0;
}

// HAZARD 22: format!() with arithmetic expressions
fn hz22_arith() -> i64 {
    let a: i64 = 10;
    let b: i64 = 7;
    let s: str = format!("{}+{}={}", a, b, a + b);
    if str_eq(s, "10+7=17") != 1 { return 1; };
    return 0;
}

// HAZARD 23: while loop with format!() inside
fn hz23_loop_format() -> i64 {
    let mut i: i64 = 0;
    let mut sb: i64 = sb_new();
    while i < 3 {
        let line: str = format!("i={}", i);
        sb_append(sb, line);
        sb_append(sb, ";");
        i = i + 1;
    };
    let result: str = sb_to_str(sb);
    if str_eq(result, "i=0;i=1;i=2;") != 1 { return 1; };
    return 0;
}

// HAZARD 24: Vec<Option<str>> patterns
fn hz24_vec_option_str() -> i64 {
    let mut v: Vec<Option<str>> = Vec::new();
    vec_push(v, Some("a"));
    vec_push(v, None);
    vec_push(v, Some("c"));
    if vec_len(v) != 3 { return 1; };
    return 0;
}

// HAZARD 25: format!() on i64 negative value
fn hz25_neg_format() -> i64 {
    let n: i64 = 0 - 42;
    let s: str = format!("{}", n);
    if str_eq(s, "-42") != 1 { return 1; };
    return 0;
}

fn main() -> i64 {
    if hz21_fn_struct_field() != 0 { println!("FAIL hz21"); return 21; };
    if hz22_arith() != 0 { println!("FAIL hz22"); return 22; };
    if hz23_loop_format() != 0 { println!("FAIL hz23"); return 23; };
    if hz24_vec_option_str() != 0 { println!("FAIL hz24"); return 24; };
    if hz25_neg_format() != 0 { println!("FAIL hz25"); return 25; };
    println!("all clean");
    return 0;
}
