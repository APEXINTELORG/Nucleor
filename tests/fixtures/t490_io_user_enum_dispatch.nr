// Hazard sweep: file IO + system + env + error propagation.

// HAZARD 41: file_write_string + file_read_string round trip
fn hz41_file_roundtrip() -> i64 {
    let path: str = "target/_hz41_probe.txt";
    file_write_string(path, "hello roundtrip");
    let read_back: str = file_read_string(path);
    if str_eq(read_back, "hello roundtrip") != 1 { return 1; };
    return 0;
}

// HAZARD 42: file_read_string of missing file
fn hz42_missing_file() -> i64 {
    let s: str = file_read_string("target/_does_not_exist_42.txt");
    // Should return empty string (lenient) or panic (strict).
    // We just want it to be DETERMINISTIC.
    if str_len(s) > 1000 { return 1; };  // sanity: not garbage
    return 0;
}

// HAZARD 43: env_get_or with default
fn hz43_env_default() -> i64 {
    let v: str = env_get_or("NUCLEOR_DEFINITELY_NOT_SET_43", "fallback");
    if str_eq(v, "fallback") != 1 { return 1; };
    return 0;
}

// HAZARD 44: format!() in error path (typical Result construction)
pub enum MyErr { NotFound(str), BadInput(str, i64) }
fn hz44_error_format() -> i64 {
    let e: MyErr = MyErr::BadInput("query", 7);
    let msg: str = match e {
        MyErr::NotFound(s) => format!("not found: {}", s),
        MyErr::BadInput(s, n) => format!("bad input: {} (code {})", s, n),
    };
    if str_eq(msg, "bad input: query (code 7)") != 1 { return 1; };
    return 0;
}

// HAZARD 45: Nested format with arithmetic + field
pub struct Stats { pub count: i64, pub total: i64 }
fn hz45_complex_format() -> i64 {
    let s: Stats = Stats { count: 4, total: 100 };
    let avg: i64 = s.total / s.count;
    let msg: str = format!("avg={} (count={}, total={})", avg, s.count, s.total);
    if str_eq(msg, "avg=25 (count=4, total=100)") != 1 { return 1; };
    return 0;
}

fn main() -> i64 {
    if hz41_file_roundtrip() != 0 { println!("FAIL hz41"); return 41; };
    if hz42_missing_file() != 0 { println!("FAIL hz42"); return 42; };
    if hz43_env_default() != 0 { println!("FAIL hz43"); return 43; };
    if hz44_error_format() != 0 { println!("FAIL hz44"); return 44; };
    if hz45_complex_format() != 0 { println!("FAIL hz45"); return 45; };
    println!("all clean");
    return 0;
}
