// v0.8.262 R14-D1 Phase 1 — @law(...) lex-time capture observable.
//
// Per audit `BUILD_PLAN_R14_algebraic_laws.md` §1 R14-D1 (CRITICAL):
// pre-v0.8.262 the compiler's lex skip path silently consumed
// `@law(...)` annotations — no AST node, no IR annotation, no
// observation. Phase 1 detects `@law(` at lex time and emits a
// position + body-length record (`info[LAW-CAPTURE]: @law at
// position N, body length M`) so future compiler phases (and
// tests) can prove the annotation was seen.
//
// Acceptance criteria (per build plan):
//   - law metadata is observable in compiler output;
//   - cold compile <= 4s (preserved);
//   - rollback path: revert the parser branch and emit a stronger
//     warning on dropped @law (kept as fallback in `simple_attribute_audit_count`).
//
// This fixture's runtime body verifies that source code containing
// `@law(...)` annotations still compiles + runs (the annotations
// remain inert at runtime — that is intentional for Phase 1; the
// observation is purely at compile time). Phase 2b will store the
// captured laws in a side table queryable from the optimizer pass.
//
// The compile-time `info[LAW-CAPTURE]` lines are observable in the
// `nuc build` output for this file. Two annotations should produce
// two LAW-CAPTURE info records.
//
// Expected: rc=0.

@law(commutative, associative)
fn add_law(a: i64, b: i64) -> i64 {
    return a + b;
}

@law(identity = 1, absorbing = 0)
fn mul_law(a: i64, b: i64) -> i64 {
    return a * b;
}

fn main() -> i64 {
    // Annotated functions still execute correctly at runtime.
    if add_law(3, 4) != 7 { return 1; };
    if add_law(0, 9) != 9 { return 2; };
    if mul_law(6, 1) != 6 { return 4; };
    if mul_law(7, 0) != 0 { return 8; };

    // Associative reassociation (the property the @law annotation
    // promises but Phase 1 does not yet enforce; runtime equality
    // still holds because the math is associative regardless).
    if add_law(add_law(1, 2), 3) != add_law(1, add_law(2, 3)) { return 16; };

    return 0;
}
