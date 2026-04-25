// T3.29 (v0.3.54) — regression test for the f64 inline
// binop-on-fn-call codegen bug fixed in v0.3.54.
//
// Pre-v0.3.54: `make_one() + make_four()` (where both fns
// return f64) miscomputed because `binop_float_type` only
// handled variable refs, float literals, struct field access,
// nested binops, and wrappers — fn calls (kind 7) fell
// through to integer add. v0.3.54 added the kind==7 branch
// using a `__fnret_<NAME>` sym entry populated at lower_fn
// entry by `populate_fn_returns_in_sym`.
//
// This fixture exercises the four primary f64 binary ops
// on fn-call results AND the nested-binop case where the
// outer + has fn-call multiplications as operands (mirrors
// the dot-product shape from the t328 struct-field test).
// Verify gate (T3.29) asserts each op prints the
// mathematically correct value.

fn one() -> f64 { return 1.0; }
fn four() -> f64 { return 4.0; }
fn eight() -> f64 { return 8.0; }
fn two() -> f64 { return 2.0; }
fn three() -> f64 { return 3.0; }
fn five() -> f64 { return 5.0; }
fn six() -> f64 { return 6.0; }

fn main() -> i64 {
    let r1: f64 = one() + four();           // 5
    print_f64(r1);
    let r2: f64 = one() - four();           // -3
    print_f64(r2);
    let r3: f64 = one() * four();           // 4
    print_f64(r3);
    let r4: f64 = eight() / four();         // 2
    print_f64(r4);
    // Nested-binop: (1*4) + (2*5) + (3*6) = 4 + 10 + 18 = 32
    let r5: f64 = one() * four() + two() * five() + three() * six();
    print_f64(r5);
    return 0;
}
