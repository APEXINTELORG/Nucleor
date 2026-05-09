// EXPECT: LAW-007 law inapplicable to function shape
// Lane 3 (F-DIAG-006): LAW-007 had no negative test in tests/err/.

#[law(Commutativity)]
fn print_value(x: i64) {
    print_int(x);
}

fn main() -> i64 {
    print_value(42);
    return 0;
}
