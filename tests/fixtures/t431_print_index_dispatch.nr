// t431_print_index_dispatch.nr — v0.3.164 regression fixture.
//
// Pre-v0.3.164, the print() type-aware dispatch handled AST kinds
// 1 (int lit), 71/72 (f64 lit), 3 (var ref), 7 (fn call), and 9
// (struct field, added v0.3.163). Index expressions (kind 10) fell
// through to the default __nucleor_print_str. For typed Vec
// elements (i64, f64, bool), `print(v[0])` treated the value as a
// pointer -- SIGSEGV when the helper dereferenced.
//
// `print(v[0])` where `v: Vec<i64>` SIGSEGV'd. Same hazard class
// as the v0.3.143 print(int) fix and v0.3.163 struct-field fix --
// adopter writes the canonical Vec-element print, gets a crash
// with no diagnostic.
//
// Fix (v0.3.164): in the print() dispatch, when arg kind is 10
// (index expression), call indexed_element_full_type on the
// receiver to get the element type with one container layer
// stripped (Vec<T> -> T), then type_base_name to strip generics,
// then dispatch on i*/u*/f32/f64/bool to the right helper.
// Falls through to the default for unknown element types.

fn main() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(10);
    v.push(20);
    v.push(30);
    // No assertion -- visual inspection / verify mirror grep checks
    // the actual values printed. Pre-fix this SIGSEGV'd on
    // print(v[0]). Reaching this return is the test.
    print(v[0]);   // i64 -- pre-fix SIGSEGV
    print(v[1]);   // i64 -- pre-fix SIGSEGV
    print(v[2]);   // i64 -- pre-fix SIGSEGV
    return 42;
}
