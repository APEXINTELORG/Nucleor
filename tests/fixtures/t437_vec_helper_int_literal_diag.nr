// t437_vec_helper_int_literal_diag.nr -- v0.3.170 regression
// fixture (positive: build succeeds with WARNING).
//
// Pre-v0.3.170, vec_get(42, 0) compiled cleanly and SIGSEGV'd at
// runtime when the helper dereferenced 42 as an NVec*. The
// existing dynamic_helper exemption deliberately bypassed the
// strict per-arg type check (because Vec<T> elements are loose
// in Nucleor's i64-everywhere ABI), so adopters got no diagnostic.
//
// Same hazard class as v0.3.162 f64_to_str(int_literal): a real
// canonical mistake produces silent runtime failure.
//
// Fix (v0.3.170): conservative literal-only WARNING. When the
// arg-0 of a vec_* helper is an INT LITERAL specifically (AST
// kind 1), emit a WARNING explaining the SIGSEGV hazard and
// suggesting `let v: Vec<T> = Vec::new();` etc. Variables
// (which legitimately hold Vec handles via the i64 ABI -- the
// compiler self-host does this pervasively) are NOT flagged.
//
// Diagnostic is INFORMATIONAL (uses print, not type_diag) so the
// build doesn't halt. Adopters who genuinely want the bit-cast
// behavior can suppress by passing through a variable.
//
// This fixture pins the well-typed case (build clean, exits 42)
// to guard against regressions in the actual Vec usage path.

fn main() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(1);
    v.push(2);
    v.push(3);
    let s: i64 = v.len();
    if s != 3 { return 1; };
    let first: i64 = vec_get(v, 0);
    if first != 1 { return 2; };
    return 42;
}
