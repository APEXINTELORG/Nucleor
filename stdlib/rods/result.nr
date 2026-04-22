// =====================================================
// rods/result — Result<T, E> type (Ok/Err)
// =====================================================
// Import: import "stdlib/rods/result.nr"
// Status: v0.1 stub; full RFC-0016 compiler-integrated `Result<T, E>`
//   ships in v0.2 (where match + ? operator land). Until then this rod
//   uses i64-as-payload via Vec<i32> tag union.
//
// Layout:
//   [0] = tag (1 = Ok, 0 = Err)
//   [1] = payload (i64; user packs/unpacks if non-i64)
// =====================================================

// Constructors
fn result_ok(val: i64) -> Vec<i32> {
    let mut r: Vec<i32> = Vec::new();
    r.push(1);
    r.push(val);
    return r;
}

fn result_err(val: i64) -> Vec<i32> {
    let mut r: Vec<i32> = Vec::new();
    r.push(0);
    r.push(val);
    return r;
}

// Predicates
fn result_is_ok(r: Vec<i32>) -> i64 { return r.get(0); }
fn result_is_err(r: Vec<i32>) -> i64 {
    if r.get(0) == 0 { return 1; };
    return 0;
}

// Extractors
fn result_unwrap(r: Vec<i32>) -> i64 {
    if r.get(0) == 0 {
        print("PANIC: result_unwrap on Err\n");
    };
    return r.get(1);
}

fn result_unwrap_or(r: Vec<i32>, default: i64) -> i64 {
    if r.get(0) == 0 { return default; };
    return r.get(1);
}

fn result_unwrap_err(r: Vec<i32>) -> i64 {
    if r.get(0) == 1 {
        print("PANIC: result_unwrap_err on Ok\n");
    };
    return r.get(1);
}

// Conversions
fn result_to_option(r: Vec<i32>) -> Vec<i32> {
    let mut o: Vec<i32> = Vec::new();
    if r.get(0) == 1 {
        o.push(1);
        o.push(r.get(1));
    } else {
        o.push(0);
        o.push(0);
    };
    return o;
}

fn result_err_to_option(r: Vec<i32>) -> Vec<i32> {
    let mut o: Vec<i32> = Vec::new();
    if r.get(0) == 0 {
        o.push(1);
        o.push(r.get(1));
    } else {
        o.push(0);
        o.push(0);
    };
    return o;
}

// Inspection
fn result_get_tag(r: Vec<i32>) -> i64 { return r.get(0); }
fn result_get_payload(r: Vec<i32>) -> i64 { return r.get(1); }
