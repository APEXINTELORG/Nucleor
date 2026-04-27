// t469_multi_payload_bind.nr -- v0.3.235 regression pin for
// RFC-NRT-004 §B (Nucleor_Translate).
//
// Reported against v0.3.231: declaring `enum E { Pair(i64, i64),
// Other }` with `match E::Pair(a, b) => { ...use a/b... }` emitted
// `@a` / `@b` undefined-global symbol references in the lowered
// LLVM IR -- multi-payload-variant bindings missed the SSA-naming
// step that single-payload bindings already had post v0.3.231 §A.
//
// Status by the time this fixture lands (v0.3.235): the bug no
// longer reproduces. Likely closed as a side effect of the
// parser-drift fix that closed §A (the same `parse_match_stmt`
// path handles both single-payload and multi-payload arm bodies,
// and the cascading-parse-failure root cause affected both).
//
// Acceptance criterion from the RFC: this fixture returns 0 from
// `check(E::Pair(1, 2))`.

pub enum E {
    Pair(i64, i64),
    Other,
}

fn check(e: E) -> i64 {
    match e {
        E::Other => return 1,
        E::Pair(a, b) => {
            if a != 1 { return 1; };
            if b != 2 { return 1; };
            return 0;
        },
    };
}

fn main() -> i64 {
    return check(E::Pair(1, 2));
}
