// RFC-0006 Design by Contract — `#[ensure(EXPR)]` mid-body
// explicit `return X;` runtime check.
//
// v0.4.247 substrate: lower_fn stashes the fn's ensure expr nid
// in sym["__current_fn_ensure_nid"] before body lowering;
// lower_stmt's kind-22 (explicit return) handler reads it and
// emits the ensure check + __nucleor_contract_ensure call before
// the ret instruction. Pre-fix, only the implicit-tail-return
// path got the check — explicit `return X;` mid-body bypassed
// the ensure silently.
//
// EXPECT: build success, runtime exit 0, output "OK rfc0006_ensure_midbody".

#[ensure(result >= 0)]
fn signum_nonneg(x: i64) -> i64 {
    if x > 0 { return 1; };
    if x < 0 { return 0; };  // 0 satisfies result >= 0
    0
}

#[ensure(result == 1 || result == 2 || result == 3)]
fn classify(x: i64) -> i64 {
    if x > 100 { return 1; };
    if x > 10 { return 2; };
    return 3;
}

fn main() -> i64 {
    let a: i64 = signum_nonneg(5);
    if a != 1 { print("FAIL signum positive"); return 1; };

    let b: i64 = signum_nonneg(0 - 5);
    if b != 0 { print("FAIL signum negative"); return 1; };

    let c: i64 = signum_nonneg(0);
    if c != 0 { print("FAIL signum zero"); return 1; };

    let d: i64 = classify(500);
    if d != 1 { print("FAIL classify big"); return 1; };

    let e: i64 = classify(50);
    if e != 2 { print("FAIL classify medium"); return 1; };

    let f: i64 = classify(5);
    if f != 3 { print("FAIL classify small"); return 1; };

    print("OK rfc0006_ensure_midbody");
    0
}
