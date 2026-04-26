// t430_print_struct_field_dispatch.nr — v0.3.163 regression fixture.
//
// Pre-v0.3.163, the print() type-aware dispatch added in v0.3.143
// only handled AST kinds 1 (int literal), 71/72 (f64 literals), 3
// (var ref), and 7 (fn call). Struct field access (kind 9) fell
// through to the default __nucleor_print_str. For non-str fields
// (f64, i64, bool), print(p.field) treated the value as a pointer
// -- SIGSEGV when the helper dereferenced.
//
// `print(p.x)` where `p.x: f64` SIGSEGV'd. Same hazard class as the
// v0.3.143 print(int) fix and v0.3.152/158 format heuristics --
// adopter writes the canonical pattern, gets a crash with no
// diagnostic.
//
// Fix (v0.3.163): in the print() dispatch, when arg kind is 9
// (field access), look up the receiver's struct type via
// expr_struct_type, then look up the field's type via
// struct_field_type. Use the field type to pick the right helper:
//   str -> __nucleor_print_str (default, unchanged)
//   i*/u* -> __nucleor_print_i64
//   f32/f64 -> __nucleor_print_f64
//   bool -> __nucleor_print_bool
// Falls through to the default for unknown field types or
// non-struct receivers.

struct Point {
    x: f64,
    y: f64,
    name: str,
    count: i64,
}

fn main() -> i64 {
    let p: Point = Point { x: 1.5, y: 2.5, name: "origin", count: 42 };
    // No assertion on output -- visual inspection / verify mirror grep
    // checks the actual values printed. Pre-fix this SIGSEGV'd on
    // print(p.x). Reaching this return is the test.
    print(p.name);   // str -- worked pre-fix
    print(p.x);      // f64 -- pre-fix SIGSEGV
    print(p.count);  // i64 -- pre-fix SIGSEGV (interpreted ptr)
    return 42;
}
