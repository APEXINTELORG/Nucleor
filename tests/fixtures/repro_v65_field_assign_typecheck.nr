// repro_v65_field_assign_typecheck.nr
//
// v0.4.65 NUC-FEEDBACK silent-coerce close for struct field
// assignment. Pre-fix `p.x = "string"` on `let p: Point` with
// `x: i64` silently stored the str pointer as i64. Same hazard
// class as v0.4.64 (indexed assign).
//
// v0.4.65 extends type_check_stmt's kind-21 (assign) handler to
// recognize kind-9 (field access) on a kind-3 var ref and validate
// RHS against the struct's declared field type via
// struct_find_type + struct_field_type. Same TYP-009 code as the
// existing var-assign mismatch.

struct Point { x: i64, y: i64, }

fn main() -> i64 {
    let mut p: Point = Point { x: 1, y: 2 };
    p.x = "string";   // TYP-009 expected
    println!("{}", p.x);
    return 0;
}
