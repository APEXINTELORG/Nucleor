// strict_intrin_explicit_modes_precedence.nr.
// Explicit source overflow modes must win over both strict env gates.

fn main() -> i32 {
    let w: i32 = wrapping { 2147483647 + 1 };
    if w != (0 - 2147483647 - 1) {
        return 1;
    };

    let max: i64 = 9223372036854775807;
    let one: i64 = 1;
    let s: i64 = saturating { max + one };
    if s != max {
        return 2;
    };

    return 0;
}

