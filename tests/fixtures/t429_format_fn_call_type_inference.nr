// t429_format_fn_call_type_inference.nr — v0.3.158 regression fixture.
//
// Pre-v0.3.158, the source-scan format heuristic added in v0.3.152
// only handled BARE IDENTIFIERS via `let X: TYPE` lookup. Function
// CALL results (e.g. `make_str()`, `helper()`) fell through to the
// default int_to_str even when the existing textual heuristics
// (`_f64(` substring, sqrt/exp/log prefixes) didn't fire.
//
// `println!("{}", make_str())` printed the string's POINTER ADDRESS.
// Same hazard class as v0.3.152 (str variables) -- a real call you
// wrote produces nonsense output with no diagnostic.
//
// Fix: companion helper infer_fn_return_type_from_source(src, fn_name)
// scans src for `fn <name>(...) -> TYPE` declarations with the same
// conflict-detection as the var version. Wired into
// fmt_conversion_for_spec when arg_expr looks like a fn call (parens
// matched, identifier head). Returns the right format helper for
// str / f64 / f32 / bool returns.

fn make_str() -> str { return "hello"; }
fn make_f64() -> f64 { return 1.5; }
fn make_int() -> i64 { return 42; }

fn main() -> i64 {
    // Visual inspection: pre-fix make_str() printed pointer address;
    // post-fix prints "hello". The fixture returns 42 if main runs to
    // completion -- print correctness is checked by the verify mirror
    // grep against captured stdout.
    println!("str: {}", make_str());
    println!("int: {}", make_int());
    println!("f64: {}", make_f64());
    return 42;
}
