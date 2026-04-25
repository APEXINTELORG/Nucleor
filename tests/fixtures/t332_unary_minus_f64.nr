// T3.32 (v0.3.57) — regression test for the f64 unary-minus
// codegen bug fixed in v0.3.57.
//
// Pre-v0.3.57: `-x` where x is f64 returned garbage (e.g.
// `-3.0` of f64 3.0 returned -1.5). Root cause: lower_expr's
// kind==5 (unary minus) emitted `const_int(0); ir_binop(3,
// zr, opr)` — always integer zero + integer subtract. For
// f64 operands this subtracted i64 bit patterns. Fix:
// dispatch to f<T>_from_scaled(0) + f<T>_sub(zr, opr) when
// the operand resolves to f-typed via binop_float_type.
//
// This fixture exercises unary minus on the four operand
// kinds production code uses: variable, struct field,
// Vec indexing, fn-call result. Verify gate (T3.32) asserts
// each negation produces the mathematically correct value.

#[repr(C)]
struct V { x: f64 }

fn make_pos() -> f64 { return 5.0; }

fn main() -> i64 {
    let v: V = V { x: 3.0 };
    let mut a: Vec<f64> = Vec::new();
    a.push(2.5);

    // Variable.
    let x: f64 = v.x;
    let r1: f64 = -x;
    print_f64(r1);   // -3.0

    // Struct field (inline).
    let r2: f64 = -v.x;
    print_f64(r2);   // -3.0

    // Vec indexing (inline).
    let r3: f64 = -a[0];
    print_f64(r3);   // -2.5

    // Fn-call result (inline).
    let r4: f64 = -make_pos();
    print_f64(r4);   // -5.0

    return 0;
}
