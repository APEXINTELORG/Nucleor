// R14 Phase 2a: true @law declarations must pass under
// `nuc test --check-laws`.
//
// Test fixture: declares two true bounded-integer algebraic laws:
//   - `add_law` is commutative + associative + has identity 0
//   - `mul_law` is commutative + associative + has identity 1
//
// Expected plain run: rc=0.
// Expected with `nuc test --check-laws`: rc=0 plus generated
// __nucleor_law_check_* tests.

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
