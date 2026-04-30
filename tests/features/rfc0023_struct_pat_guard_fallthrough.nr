// RFC-0023 regression-guard fixture — v0.4.202.
//
// Locks in the v0.4.202 fix for struct-destructure-with-guard
// fall-through. Pre-fix `match p { Point { x, y } if cond => A,
// Point { x, y } => B }` always took the FIRST arm regardless
// of guard evaluation. The fix at lower_expr's __struct arm
// (compiler/nucleor_s1_compiler.nr:15841) wired the guard
// branch on by mirroring the __wild pattern.
//
// This fixture proves the fall-through is correct in 4 distinct
// scenarios. Any future ship that re-breaks this halts the
// verify gate immediately.

struct Point { x: i32, y: i32 }

enum Sign { Pos(i32), Neg(i32) }

fn check_origin(p: Point) -> i32 {
    match p {
        Point { x, y } if x == 0 && y == 0 => 100,
        Point { x, y } => x + y,
    }
}

fn check_x_positive(p: Point) -> i32 {
    match p {
        Point { x, y } if x > 0 => 1,
        Point { x, y } if x < 0 => -1,
        Point { x, y } => 0,
    }
}

fn check_enum_with_guard(s: Sign) -> i32 {
    match s {
        Sign::Pos(n) if n > 100 => 999,
        Sign::Pos(n) => n,
        Sign::Neg(n) => 0 - n,
    }
}

fn main() -> i32 {
    // Origin case — guard hits.
    if check_origin(Point { x: 0, y: 0 }) != 100 { print("FAIL origin guard hit"); return 1; };
    // Off-origin — first guard fails (x=3, y=4 not both 0); falls through.
    if check_origin(Point { x: 3, y: 4 }) != 7 { print("FAIL origin guard fallthrough"); return 1; };
    // Half-zero — guard fails (y=99 not 0); falls through.
    if check_origin(Point { x: 0, y: 99 }) != 99 { print("FAIL origin half-zero fallthrough"); return 1; };

    // Two consecutive guards.
    if check_x_positive(Point { x: 5, y: 0 }) != 1 { print("FAIL x>0 guard hit"); return 1; };
    if check_x_positive(Point { x: -5, y: 0 }) != -1 { print("FAIL x<0 guard hit (fallthrough first)"); return 1; };
    if check_x_positive(Point { x: 0, y: 0 }) != 0 { print("FAIL x=0 default fallthrough"); return 1; };

    // Enum with guard.
    if check_enum_with_guard(Sign::Pos(200)) != 999 { print("FAIL enum guard hit"); return 1; };
    if check_enum_with_guard(Sign::Pos(50)) != 50 { print("FAIL enum guard fallthrough"); return 1; };
    if check_enum_with_guard(Sign::Neg(7)) != -7 { print("FAIL enum next variant"); return 1; };

    print("OK rfc0023_struct_pat_guard_fallthrough");
    0
}
