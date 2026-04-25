// T3.30 (v0.3.55) — regression test for the f64 inline
// binop-on-Vec-indexing codegen bug fixed in v0.3.55.
//
// Pre-v0.3.55: `v[0] + v[1]` (where v: Vec<f64>) miscomputed
// because `binop_float_type` only handled the AST kinds
// fixed in v0.3.53/v0.3.54 — Vec indexing (kind 10) fell
// through to integer add and returned `inf`/garbage. Root
// cause was upstream: the existing __type_<vname> sym entry
// only stored the BASE name ("Vec") because type_base_name
// strips generics. v0.3.55 added a parallel
// __fulltype_<vname> entry that preserves the generic so
// the kind==10 dispatcher can extract the element type.
//
// This fixture exercises the four primary f64 binary ops
// on Vec<f64> indexing AND the nested-binop case. Verify
// gate (T3.30) asserts each op prints the correct value.

fn main() -> i64 {
    let mut v: Vec<f64> = Vec::new();
    v.push(1.0);
    v.push(4.0);
    v.push(2.0);
    v.push(8.0);
    v.push(3.0);
    v.push(5.0);
    v.push(6.0);
    let r1: f64 = v[0] + v[1];           // 1 + 4 = 5
    print_f64(r1);
    let r2: f64 = v[0] - v[1];           // 1 - 4 = -3
    print_f64(r2);
    let r3: f64 = v[0] * v[1];           // 1 * 4 = 4
    print_f64(r3);
    let r4: f64 = v[3] / v[1];           // 8 / 4 = 2
    print_f64(r4);
    // Nested: v[0]*v[1] + v[2]*v[5] + v[4]*v[6]
    //       = 1*4 + 2*5 + 3*6 = 32
    let r5: f64 = v[0] * v[1] + v[2] * v[5] + v[4] * v[6];
    print_f64(r5);
    return 0;
}
