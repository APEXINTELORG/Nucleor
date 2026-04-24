// option_result_basic.nr — T1.2 (v0.2.336) Option<T> + Result<T, E>
// constructor sugar + match destructuring + if let.
// Promotes the option_result_f64 quarantine spec into the gate
// using the supported `Some(x)` paren-binding syntax (struct-style
// `Some { value }` is a v0.6 sum-type-IR follow-up).
import "stdlib/rods/option.nr"
import "stdlib/rods/result.nr"

fn maybe_div(a: i64, b: i64) -> Vec<i32> {
    if b == 0 { return None; };
    return Some(a / b);
}

fn lookup(key: i64) -> Vec<i32> {
    if key == 1 { return Ok(100); };
    if key == 2 { return Ok(200); };
    return Err(0 - 1);
}

fn main() -> i32 {
    let mut fail: i64 = 0;

    // T1: Some(x) constructor + match destructure
    let r1 = maybe_div(10, 2);
    match r1 {
        Some(v) => { if v != 5 { fail = fail + 1; print("FAIL: Some payload\n"); }; },
        None => { fail = fail + 1; print("FAIL: expected Some\n"); },
    };

    // T2: None constructor + match
    let r2 = maybe_div(5, 0);
    match r2 {
        Some(v) => { fail = fail + 1; print("FAIL: expected None, got Some\n"); },
        None => { let _ = 0; },
    };

    // T3: Ok(x) constructor + match destructure
    let r3 = lookup(1);
    match r3 {
        Ok(v) => { if v != 100 { fail = fail + 1; print("FAIL: Ok payload\n"); }; },
        Err(e) => { fail = fail + 1; print("FAIL: expected Ok\n"); },
    };

    // T4: Err(e) constructor + match
    let r4 = lookup(99);
    match r4 {
        Ok(v) => { fail = fail + 1; print("FAIL: expected Err\n"); },
        Err(e) => { if e != (0 - 1) { fail = fail + 1; print("FAIL: Err payload\n"); }; },
    };

    // T5: if let sugar
    let r5 = maybe_div(20, 4);
    if let Some(x) = r5 {
        if x != 5 { fail = fail + 1; print("FAIL: if let Some\n"); };
    };

    if fail != 0 { return 1; };
    print("OK option_result_basic\n");
    return 0;
}
