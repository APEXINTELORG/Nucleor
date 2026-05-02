// Test where clause syntax on functions.
//
// v0.6.11: where-clause bounds are now captured at parse time and
// validated by TYP-019 (trait must exist). Pre-v0.6.11 the bounds
// were silently parse-skipped, so this fixture used fictional
// `Display + Clone` names. v0.6.11 defines the traits locally so
// the where-clause parses cleanly with real bounds — and the fix
// now actively exercises that bounds capture, not just the parse
// surface.

trait Display { fn display(self) -> i64; }
trait Clone   { fn clone(self) -> i64; }

fn process<T>(x: T) -> T where T: Display + Clone {
    return x;
}

fn main() -> i32 {
    let val: i32 = 42;
    print_int(val);
    0
}
