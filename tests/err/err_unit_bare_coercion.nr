// EXPECT: error[TYP-007] bare numeric literal cannot initialize a unit value
// RFC-0005 archive guard: bare numbers do not carry a dimension tag. This is
// the Mars Climate Orbiter failure class, so the build path now fails closed
// instead of silently erasing the unit annotation.

fn main() -> i32 {
    let force: unit<i32, N> = 42;
    0
}
