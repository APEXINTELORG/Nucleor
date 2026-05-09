// EXPECT: error[MATCH-016]
// Lane 1 audit fix (2026-05-08) — closes F-002 (cross-enum match
// silent miscompile). Pre-fix `match a: A { B::On => ..., B::Off
// => ... }` was accepted because both enums lower to integer tags
// and matched by tag value; A::Red (tag 0) silently matched B::On
// (tag 0). Post-fix the pattern-vs-scrutinee enum identity check
// fires.
enum A { Red, Blue }
enum B { On, Off }

fn main() -> i32 {
    let a: A = A::Red;
    let r: i64 = match a {
        B::On  => 1,
        B::Off => 2,
    };
    print_int(r as i32);
    0
}
