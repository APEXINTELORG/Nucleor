// v0.8.263 R14-D3 Phase 1 — `--check-laws` flag wired (no longer ignored).
//
// Per audit `BUILD_PLAN_R14_algebraic_laws.md` §1 R14-D3 (CRITICAL):
// pre-v0.8.263 `nuc_router.ps1:677-680` matched `--check-laws` in
// the ignored-flags switch branch and silently dropped the value.
// Adopters running `nuc test --check-laws` got zero feedback that
// the flag had any effect. Phase 1 wires the flag to a visible
// acknowledgment + surfaces the existing `info[LAW-CAPTURE]`
// records emitted by R14-D1 (v0.8.262) at lex time.
//
// Phase 1 acceptance criteria (this ship):
//   - flag is not ignored: an info[CHECK-LAWS] line emits when
//     `--check-laws` is passed;
//   - LAW-CAPTURE pipeline still fires (verified at compile time);
//   - cold compile <= 4s (preserved).
//
// Phase 2 acceptance (future ship per build plan §1 R14-D3):
//   - generate bounded property tests for each captured @law;
//   - true law passes (this fixture);
//   - false law fails with nonzero exit (separate err fixture).
//
// Test fixture: declares two TRUE algebraic laws:
//   - `add_law` is commutative + associative + has identity 0
//   - `mul_law` is commutative + associative + has identity 1
// Both laws hold for the integer body, so under Phase 2 property
// testing this fixture is expected to pass with rc=0.
//
// Phase 1 just verifies the runtime path is sane (annotated fns
// execute correctly) and that `bin/nucleor.exe build` emits the
// expected LAW-CAPTURE records.
//
// Expected: rc=0.

@law(commutative, associative, identity = 0)
fn add_law(a: i64, b: i64) -> i64 {
    return a + b;
}

@law(commutative, associative, identity = 1)
fn mul_law(a: i64, b: i64) -> i64 {
    return a * b;
}

fn main() -> i64 {
    // Commutativity (true law)
    if add_law(3, 5) != add_law(5, 3) { return 1; };
    if mul_law(7, 6) != mul_law(6, 7) { return 2; };

    // Associativity (true law)
    if add_law(add_law(1, 2), 3) != add_law(1, add_law(2, 3)) { return 4; };
    if mul_law(mul_law(2, 3), 4) != mul_law(2, mul_law(3, 4)) { return 8; };

    // Identity (true law)
    if add_law(42, 0) != 42 { return 16; };
    if add_law(0, 42) != 42 { return 32; };
    if mul_law(42, 1) != 42 { return 64; };
    if mul_law(1, 42) != 42 { return 128; };

    return 0;
}
