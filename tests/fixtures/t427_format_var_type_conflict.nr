// t427_format_var_type_conflict.nr — v0.3.153 regression fixture.
//
// Pre-v0.3.153 (i.e. v0.3.152), the bare `{}` heuristic added in
// v0.3.152 used a source-level scan for `let X: TYPE` declarations
// to infer the format type. The scan picked the FIRST match it found
// in src -- which when the same identifier was declared with
// different types in different functions, picked the WRONG type.
//
// Concretely: with `let x: str` in helper() and `let x: i64` in
// main(), `println!("{}", x)` in main treated x as str and called
// __nucleor_print_str on the i64 value 999 -- SIGSEGV when the
// helper dereferenced 999 as a const char *.
//
// New silent-miscompute INTRODUCED by the v0.3.152 fix. Caught
// during v0.3.152 ship-validation probing and rolled forward in
// v0.3.153 (not reverted -- the heuristic still helps; just made
// conservative).
//
// Fix: scan ALL `let X: TYPE` declarations and only return TYPE if
// every declaration agrees. On conflict, fall back to int_to_str
// (the existing default). Worst case the adopter sees the original
// int-as-pointer behavior and switches to explicit `:s` / `:f` --
// still a hazard but the same one we had pre-v0.3.152, NOT a worse
// one. Conservative-by-construction.
//
// Returns 42 if the conflict-detection fires (println prints 999
// as int) and the program doesn't SIGSEGV.

fn helper_with_x_as_str() -> str {
    let x: str = "from_helper";
    return x;
}

fn main() -> i64 {
    let x: i64 = 999;
    println!("local x: {}", x);
    // No assertion on the print output -- if the v0.3.152 bug were
    // present we'd never reach here (SIGSEGV). Reaching this return
    // is the test.
    return 42;
}
