// v0.8.265 R14-D2 Phase 1 — opt_law_rewrite_block scaffold (no-op).
//
// Per audit `BUILD_PLAN_R14_algebraic_laws.md` §1 R14-D2 (HIGH):
// pre-v0.8.265 the optimizer's pass list (`opt_fn` driver) had no
// slot for law-aware rewrites. Phase 1 adds `opt_law_rewrite_block`
// as a metadata-only no-op pass wired into both iterations of
// `opt_fn`. Phase 2 will: (1) consume @law metadata stored at lex
// (R14-D1), (2) gate behind a proof flag from `--check-laws`
// property-test results, (3) enable the first concrete rewrite
// (`f(a, identity) → a`).
//
// Phase 1 acceptance criteria (this ship):
//   - the pass exists in opt_fn's pass list (observable scaffold);
//   - returns 0 rewrites (no-op);
//   - "false law never triggers rewrite" trivially holds because
//     no law triggers any rewrite yet;
//   - cold compile <= 4s (preserved).
//
// This fixture exercises three @law-annotated functions through
// `opt_fn` (every `nuc build` runs the optimizer driver) and
// verifies their runtime semantics are unchanged. Phase 2 will
// extend this fixture to verify the optimizer ACTUALLY rewrites
// `add_law(x, 0)` → `x` when the property test confirms the
// identity law.
//
// Expected: rc=0.

@law(commutative, associative, identity = 0)
fn add_law(a: i64, b: i64) -> i64 {
    return a + b;
}

@law(commutative, associative, identity = 1, absorbing = 0)
fn mul_law(a: i64, b: i64) -> i64 {
    return a * b;
}

@law(idempotent)
fn max_law(a: i64, b: i64) -> i64 {
    if a > b { return a; };
    return b;
}

fn main() -> i64 {
    // Identity law (Phase 2 will rewrite these as `x` directly):
    if add_law(7, 0) != 7 { return 1; };
    if add_law(0, 9) != 9 { return 2; };
    if mul_law(11, 1) != 11 { return 4; };
    if mul_law(1, 13) != 13 { return 8; };

    // Absorbing law (Phase 2 will rewrite `mul_law(x, 0)` → `0`):
    if mul_law(42, 0) != 0 { return 16; };
    if mul_law(0, 42) != 0 { return 32; };

    // Commutativity (Phase 2 will allow free reordering):
    if add_law(3, 5) != add_law(5, 3) { return 64; };
    if mul_law(7, 6) != mul_law(6, 7) { return 128; };

    // Associativity (Phase 2 will allow free reassociation):
    if add_law(add_law(1, 2), 3) != add_law(1, add_law(2, 3)) { return 256; };

    // Idempotence (Phase 2: `max_law(x, x)` → `x`):
    if max_law(7, 7) != 7 { return 512; };
    if max_law(0, 0) != 0 { return 1024; };

    return 0;
}
