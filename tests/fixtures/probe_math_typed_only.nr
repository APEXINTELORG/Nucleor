// Probe NUC-FEEDBACK-011: importing only `math_typed.nr` (no special
// rod) must NOT pull in unresolved f64_erf/f64_betainc/etc symbols.
// Pre-fix this would have clang-failed with "undefined value" errors
// on bin/nucleor.exe < v0.3.230 even when the program never calls
// the special wrappers. Post-fix: the special wrappers live in a
// separate rod so the base typed-math import stays clean.

import "stdlib/rods/math_typed.nr"

fn main() -> i64 {
    let x: f64 = sqrt_f64(4.0);
    let y: f64 = exp_f64(0.0);
    let s: f64 = sin_f64(0.0);
    if x != 2.0 { return 1; };
    if y != 1.0 { return 1; };
    if s != 0.0 { return 1; };
    return 0;
}
