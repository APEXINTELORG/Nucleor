// t442_for_loop_var_print_dispatch.nr -- v0.3.175 regression
// fixture.
//
// Pre-v0.3.175, the for-loop lowering bound the loop variable's
// name to its alloca slot but did NOT register __type_<name> in
// the sym table. So print(i) for the loop var fell through the
// kind-3 (var ref) print() dispatch (which looks up __type_<name>)
// and defaulted to print_str -- which dereferenced the i64 loop
// value as a const char * and SIGSEGV'd.
//
// Same hazard class as v0.3.143/163/164/165/168 print() dispatch
// gaps -- adopter writes a canonical for-loop and gets a crash
// with no diagnostic.
//
// Fix (v0.3.175):
//   - kind 28 (range for-loop): unconditionally set
//     __type_<name> to "i64" (range elements are always i64).
//   - kind 49 (iter for-loop): use indexed_element_full_type to
//     derive the element type from the iterator (Vec<T> -> T)
//     and set __type_<name> accordingly. Falls through silently
//     when the iterator type isn't a known container.

fn main() -> i64 {
    // Range loop -- prints 0, 1, 2.
    for i in 0..3 {
        print(i);
    }

    // Iter loop over Vec<i64> -- prints 10, 20, 30.
    let mut v: Vec<i64> = Vec::new();
    v.push(10); v.push(20); v.push(30);
    for x in v {
        print(x);
    }

    return 42;
}
