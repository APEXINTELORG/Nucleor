// t433_println_format_extended_heuristics.nr -- v0.3.166 regression
// fixture.
//
// Pre-v0.3.166, the println! `{}` source-scan format heuristic
// (added v0.3.152, extended v0.3.158) only recognized:
//   - bare ident (`println!("{}", x)`)
//   - fn call shape (`println!("{}", f())`)
// Three other adopter-canonical shapes silently miscompiled
// (printed bit patterns or pointer addresses):
//   - struct field access (`println!("{}", p.x)`)
//   - index expression (`println!("{}", v[0])`)
//   - cast (`println!("{}", n as f64)`)
//
// Same hazard class as v0.3.137-150 silent miscomputes -- a real
// expression you wrote produces garbage with no diagnostic.
//
// Fix (v0.3.166):
//   1. New helper infer_struct_field_type_from_source(src, struct,
//      field) scans `struct STRUCT { ... field: TYPE, ... }`.
//   2. Three new heuristics in fmt_conversion_for_spec:
//      - cast: detect ` as TYPE` suffix, dispatch by TYPE
//      - struct field: detect `<recv>.<field>`, look up via the
//        new helper
//      - index: detect `<recv>[...]`, strip Vec<T> via the existing
//        strip_container_one_level
//   3. infer_var_type_from_source upgraded to track `<>` depth so
//      `Vec<f64>` returns "Vec<f64>" (full type) instead of "Vec"
//      (truncated). Existing scalar-name callers unaffected.
//
// Visual inspection: pre-fix, p.x / v[0] / cast printed bit
// patterns; p.name printed pointer address. Post-fix prints actual
// values. Returning 42 on full main() completion is the gate.

struct Point { x: f64, name: str }

fn main() -> i64 {
    let p: Point = Point { x: 1.5, name: "origin" };
    println!("p.x={}", p.x);
    println!("p.name={}", p.name);

    let mut v: Vec<f64> = Vec::new();
    v.push(3.14);
    println!("v[0]={}", v[0]);

    let n: i64 = 42;
    println!("cast={}", n as f64);
    return 42;
}
