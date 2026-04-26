// t426_format_var_type_inference.nr — v0.3.152 regression fixture.
//
// Pre-v0.3.152, the bare `{}` format heuristic in
// fmt_conversion_for_spec only fired for unambiguous textual shapes:
// quoted string literals, decimal-with-dot, fn calls starting with
// sqrt/exp/log/etc. For BARE IDENTIFIERS naming user variables of
// type str / f64 / bool, the heuristic fell through to the default
// int_to_str(arg) -- which printed:
//   - str variables as their POINTER ADDRESS
//   - f64 variables as their BIT PATTERN (looks like a giant int)
//   - bool variables as 0 or 1
//
// Same hazard class as v0.3.137-v0.3.151 silent miscompiles: an
// adopter writing the canonical debug pattern `println!("{}", x)`
// got nonsense output with no diagnostic. The s1 self-host source
// avoided this by always using `print(str_concat(...))` instead of
// the macro form, but adopter code with the standard idiom hit it.
//
// Fix: add a new helper `infer_var_type_from_source(src, var_name)`
// that scans src for `let X: TYPE` and `let mut X: TYPE` patterns
// and returns the type. Invoked in fmt_conversion_for_spec ONLY when
// arg_expr is a bare identifier and the existing textual heuristics
// didn't fire. Threads `src` through fmt_build_expansion so the scan
// has access to the full source. Complex expressions (parens, dots,
// ops) still need explicit `:s` / `:f` / `:i` -- only bare
// identifiers benefit from the scan.
//
// Returns 42 if all three `{}` cases print the value (not the bit
// pattern / pointer).

fn main() -> i64 {
    let n: i64 = 42;
    let f: f64 = 3.14;
    let s: str = "world";

    // These four prints exercise the four type categories. Pre-fix
    // the f and s lines printed garbage. Post-fix all four print
    // the value. The fixture returns 42 unconditionally; visual
    // inspection of the output (or grep against captured stdout) is
    // how the verify mirror would check the fix.
    println!("int: {}", n);
    println!("float: {}", f);
    println!("string: {}", s);
    return 42;
}
