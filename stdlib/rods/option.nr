// =====================================================
// rods/option — Option<T> type (Some/None)
// =====================================================
// Import: import "stdlib/rods/option.nr"
// Status: v0.1 stub; full RFC-0016 compiler-integrated `Option<T>`
//   ships in v0.2 (where match + ? operator land). Until then this rod
//   uses i64-as-payload via Vec<i32> tag union.
//
// Layout:
//   [0] = tag (1 = Some, 0 = None)
//   [1] = payload (i64; user packs/unpacks if non-i64)
// =====================================================

// Constructors
fn option_some(val: i64) -> Vec<i32> {
    let mut o: Vec<i32> = Vec::new();
    o.push(1);
    o.push(val);
    return o;
}

fn option_none() -> Vec<i32> {
    let mut o: Vec<i32> = Vec::new();
    o.push(0);
    o.push(0);
    return o;
}

// Predicates
fn option_is_some(o: Vec<i32>) -> i64 { return o.get(0); }
fn option_is_none(o: Vec<i32>) -> i64 {
    if o.get(0) == 0 { return 1; };
    return 0;
}

// Extractors
fn option_unwrap(o: Vec<i32>) -> i64 {
    if o.get(0) == 0 {
        print("PANIC: option_unwrap on None\n");
    };
    return o.get(1);
}

fn option_unwrap_or(o: Vec<i32>, default: i64) -> i64 {
    if o.get(0) == 0 { return default; };
    return o.get(1);
}

fn option_unwrap_or_else_zero(o: Vec<i32>) -> i64 {
    if o.get(0) == 0 { return 0; };
    return o.get(1);
}

// Conversions
fn option_to_result(o: Vec<i32>, err_val: i64) -> Vec<i32> {
    let mut r: Vec<i32> = Vec::new();
    if o.get(0) == 1 {
        r.push(1);
        r.push(o.get(1));
    } else {
        r.push(0);
        r.push(err_val);
    };
    return r;
}

// Inspection (pure; no payload extraction)
fn option_get_tag(o: Vec<i32>) -> i64 { return o.get(0); }
fn option_get_payload(o: Vec<i32>) -> i64 { return o.get(1); }
