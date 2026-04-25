// T3.42 (v0.3.67) — regression test for indexing on fn-call
// result inside inline f64 binops.
//
// Pre-v0.3.67: `make_vec()[0] + make_vec()[1]` returned -0.0
// because the kind==10 dispatcher couldn't extract the
// fn-call's full return type. populate_fn_returns_in_sym
// (v0.3.54) only stored the BASE name (`Vec`, not
// `Vec<f64>`) via type_base_name, so the Vec<T> parser had
// nothing to chew on. v0.3.67 added a parallel
// `__fnfulltype_<NAME>` sym entry preserving the generic,
// then extended the kind==10 branches in BOTH
// binop_float_type and expr_struct_type to handle kind 7
// operands.
//
// Closes the next cell of the v0.3.66 composition matrix:
//
//   Operand kind of indexed expr | binop | expr_struct
//   3 (var ref v[i])             | v0.3.55 | v0.3.59
//   9 (struct field self.s[i])   | v0.3.65 | v0.3.66
//   7 (fn-call make_vec()[i])    | v0.3.67 | v0.3.67  (this)
//
// Production-relevant: factory functions returning Vec<T>
// or [T; N] are common (configuration loaders, bias
// estimators, calibration tables) and inline-indexing them
// keeps the call site readable.

fn make_vec() -> Vec<f64> {
    let mut v: Vec<f64> = Vec::new();
    v.push(3.0);
    v.push(4.0);
    v.push(5.0);
    return v;
}

#[repr(C)]
struct V { x: f64, y: f64 }

fn make_vstruct() -> Vec<V> {
    let mut v: Vec<V> = Vec::new();
    v.push(V { x: 1.0, y: 2.0 });
    v.push(V { x: 3.0, y: 4.0 });
    return v;
}

fn main() -> i32 {
    // Binop on fn-call indexing — the original bug.
    let r1: f64 = make_vec()[0] + make_vec()[1];
    print_f64(r1);   // 7.0

    let r2: f64 = make_vec()[0] * make_vec()[2];
    print_f64(r2);   // 15.0

    // Field access on fn-call indexing — uses both v0.3.67 paths
    // (expr_struct_type kind 7 + kind 10 composition).
    let r3: f64 = make_vstruct()[0].x + make_vstruct()[1].y;
    print_f64(r3);   // 5.0

    return 0;
}
