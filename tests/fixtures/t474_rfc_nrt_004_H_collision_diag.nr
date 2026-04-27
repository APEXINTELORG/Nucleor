// t474_rfc_nrt_004_H_collision_diag.nr -- v0.4.1 negative
// regression for RFC-NRT-004 §H (Nucleor_Translate).
//
// Pre-fix: importing two modules that both declare a `pub fn`
// with the same name produced a clang link error "invalid
// redefinition of function 'X'" deep in the compile log,
// far from the actual culprits.
//
// Post-fix: the s1 emitter detects duplicate top-level fn names
// across the merged module set and panics with a precise
// diagnostic naming the duplicate symbol + recommending the
// `<module>_<fn>` rename convention.
//
// This fixture deliberately CRASHES with the diagnostic. The
// verify gate Step asserts: (a) build exits non-zero AND
// (b) stderr/stdout contains the "duplicate top-level fn name"
// diagnostic AND (c) names 'error_kind_to_str' as the duplicate.

import "tests/fixtures/t474_rfc_nrt_004_H_module_a_aux.nr"
import "tests/fixtures/t474_rfc_nrt_004_H_module_b_aux.nr"

fn main() -> i64 {
    let a: AKind = AKind::AOne;
    let b: BKind = BKind::BOne;
    println!("{}", error_kind_to_str(a));
    println!("{}", error_kind_to_str(b));
    return 0;
}
