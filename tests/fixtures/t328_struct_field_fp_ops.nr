// T3.28 (v0.3.53) — regression test for the f64 inline
// binary-op-on-struct-field codegen bug fixed in v0.3.53.
//
// Pre-v0.3.53: `a.x * b.x` directly in expression position
// when both operands were loaded from struct-by-value args
// miscomputed because `binop_float_type` only handled
// variable refs and float literals. v0.3.53 extended it to
// also recognize struct field accesses (kind 9), nested
// binops (kind 4), and parenthesized wrappers (kinds 90/91/92).
//
// This fixture exercises the four primary f64 binary ops
// (+, -, *, /) in inline form on struct-field operands AND
// in nested-binop form (the (a.x*b.x) + (a.y*b.y) shape that
// requires the kind-4 recursion fix). Verify gate (T3.28)
// asserts each op prints the mathematically correct value.

#[repr(C)]
struct V { x: f64, y: f64, z: f64 }

#[export]
fn check_add(a: V, b: V) -> i64 {
    let r: f64 = a.x + b.x;
    print_f64(r);
    return 0;
}

#[export]
fn check_sub(a: V, b: V) -> i64 {
    let r: f64 = a.x - b.x;
    print_f64(r);
    return 0;
}

#[export]
fn check_mul(a: V, b: V) -> i64 {
    let r: f64 = a.x * b.x;
    print_f64(r);
    return 0;
}

#[export]
fn check_div(a: V, b: V) -> i64 {
    let r: f64 = a.x / b.x;
    print_f64(r);
    return 0;
}

#[export]
fn check_dot(a: V, b: V) -> i64 {
    // Nested binops — exercises the kind-4 recursion fix.
    let r: f64 = a.x * b.x + a.y * b.y + a.z * b.z;
    print_f64(r);
    return 0;
}

fn main() -> i64 {
    let _: i64 = check_add(V{x:1.0,y:0.0,z:0.0}, V{x:4.0,y:0.0,z:0.0}); // 5.0
    let _: i64 = check_sub(V{x:1.0,y:0.0,z:0.0}, V{x:4.0,y:0.0,z:0.0}); // -3.0
    let _: i64 = check_mul(V{x:1.0,y:0.0,z:0.0}, V{x:4.0,y:0.0,z:0.0}); // 4.0
    let _: i64 = check_div(V{x:8.0,y:0.0,z:0.0}, V{x:4.0,y:0.0,z:0.0}); // 2.0
    let _: i64 = check_dot(V{x:1.0,y:2.0,z:3.0}, V{x:4.0,y:5.0,z:6.0}); // 32.0
    return 0;
}
