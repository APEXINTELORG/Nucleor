// Additional hazard probes against v0.4.14.

pub struct Pair { pub a: i64, pub b: str }

// HAZARD 6: Method-style call return-type dispatch in format
fn hz6_method_str() -> i64 {
    let s: str = format!("{}", str_concat("hello ", "world"));
    if str_eq(s, "hello world") != 1 { return 1; };
    return 0;
}

// HAZARD 7: Vec<str> indexing in format
fn hz7_vec_index() -> i64 {
    let mut v: Vec<str> = Vec::new();
    vec_push(v, "alpha");
    vec_push(v, "beta");
    let s: str = format!("got: {}", vec_get(v, 1));
    if str_eq(s, "got: beta") != 1 { return 1; };
    return 0;
}

// HAZARD 8: Field access in format chain
fn hz8_field_in_format() -> i64 {
    let p: Pair = Pair { a: 42, b: "answer" };
    let s: str = format!("{} = {}", p.b, p.a);
    if str_eq(s, "answer = 42") != 1 { return 1; };
    return 0;
}

// HAZARD 9: nested match with Result<Option<str>, str>
fn hz9_nested_result() -> i64 {
    let r: Result<Option<str>, str> = Ok(Some("payload"));
    match r {
        Err(e) => return 1,
        Ok(inner) => {
            match inner {
                None => return 1,
                Some(s) => {
                    let out: str = format!("inner={}", s);
                    if str_eq(out, "inner=payload") != 1 { return 1; };
                },
            };
        },
    };
    return 0;
}

// HAZARD 10: match dispatch on negative ints (sign-extension hazards)
fn hz10_neg_int() -> i64 {
    let x: i64 = 0 - 42;
    let kind: i64 = if x < 0 { 1 } else { 2 };
    if kind != 1 { return 1; };
    return 0;
}

fn main() -> i64 {
    if hz6_method_str() != 0 { println!("FAIL hz6"); return 6; };
    if hz7_vec_index() != 0 { println!("FAIL hz7"); return 7; };
    if hz8_field_in_format() != 0 { println!("FAIL hz8"); return 8; };
    if hz9_nested_result() != 0 { println!("FAIL hz9"); return 9; };
    if hz10_neg_int() != 0 { println!("FAIL hz10"); return 10; };
    println!("all clean");
    return 0;
}
