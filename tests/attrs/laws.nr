// laws.nr — @law identity/associative/commutative/absorbing are eligible
// for future compile-time rewrite by the optimizer and for bounded integer
// checks under `nuc test --check-laws`. Canonical schema lives at
// `docs/spec/Nucleor_Algebraic_Laws_Schema.md` (locked v0.8.264 per
// audit R14-D5). This fixture's spellings (`commutative`, `associative`,
// `identity=N`, `absorbing=N`) are all canonical.
@law(commutative, associative, identity=0)
fn add(a: i64, b: i64) -> i64 {
    return a + b;
}

@law(commutative, associative, identity=1, absorbing=0)
fn mul(a: i64, b: i64) -> i64 {
    return a * b;
}

fn main() -> i64 {
    let mut fail: i64 = 0;

    // identity-eligible: add(x, 0) -> x and add(0, x) -> x
    if add(7, 0) != 7 { print("FAIL laws: add identity right"); fail = fail + 1; };
    if add(0, 7) != 7 { print("FAIL laws: add identity left"); fail = fail + 1; };

    // associative-eligible: any reassociation must yield the same answer
    let s1: i64 = add(add(1, 2), 3);
    let s2: i64 = add(1, add(2, 3));
    if s1 != s2 { print("FAIL laws: add associative"); fail = fail + 1; };

    // mul identity + absorbing
    if mul(13, 1) != 13 { print("FAIL laws: mul identity"); fail = fail + 1; };
    if mul(13, 0) != 0 { print("FAIL laws: mul absorbing"); fail = fail + 1; };

    if fail == 0 { print("OK laws"); return 0; };
    return 1;
}
