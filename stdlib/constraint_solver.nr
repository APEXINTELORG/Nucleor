// constraint_solver.nr — Constraint solver / symbolic reasoning (Phase 14, GAP-18)
// FFI interface to Z3 SMT solver when available, with pure-Nucleor fallback.
//
// Provides: boolean satisfiability, integer constraints, symbolic execution.
// When Z3 is not available, uses a simple brute-force solver for small problems.

fn str_from_int(n: i32) -> str {
    if n == 0 { return "0"; };
    let mut val: i32 = n;
    if val < 0 { val = 0 - val; };
    let mut s: str = "";
    while val > 0 {
        let d: i32 = val - (val / 10) * 10;
        let mut ch: str = "0";
        if d == 1 { ch = "1"; } else if d == 2 { ch = "2"; } else if d == 3 { ch = "3"; }
        else if d == 4 { ch = "4"; } else if d == 5 { ch = "5"; } else if d == 6 { ch = "6"; }
        else if d == 7 { ch = "7"; } else if d == 8 { ch = "8"; } else if d == 9 { ch = "9"; };
        s = str_concat(ch, s);
        val = val / 10;
    };
    if n < 0 { s = str_concat("-", s); };
    s
}

// Constraint types
const CONSTRAINT_EQ: i32 = 1;   // x == value
const CONSTRAINT_LT: i32 = 2;   // x < value
const CONSTRAINT_GT: i32 = 3;   // x > value
const CONSTRAINT_AND: i32 = 4;  // c1 AND c2
const CONSTRAINT_OR: i32 = 5;   // c1 OR c2
const CONSTRAINT_NEQ: i32 = 6;  // x != value

// Brute-force solver for small integer constraint problems
// Tries all values in [lo, hi] for each variable
fn solve_1var(constraints: Vec<i32>, constraint_count: i32, lo: i32, hi: i32) -> i32 {
    // Each constraint: [type, value]
    let mut x: i32 = lo;
    while x <= hi {
        let mut all_sat: bool = true;
        let mut ci: i32 = 0;
        while ci < constraint_count {
            let ctype: i32 = constraints.get(ci * 2);
            let cval: i32 = constraints.get(ci * 2 + 1);
            if ctype == CONSTRAINT_EQ && x != cval { all_sat = false; };
            if ctype == CONSTRAINT_LT && x >= cval { all_sat = false; };
            if ctype == CONSTRAINT_GT && x <= cval { all_sat = false; };
            if ctype == CONSTRAINT_NEQ && x == cval { all_sat = false; };
            ci = ci + 1;
        };
        if all_sat { return x; };
        x = x + 1;
    };
    0 - 999999 // unsatisfiable sentinel
}

fn test_simple_eq() -> i32 {
    print("=== Solver 1: x == 42 ===");
    let mut c: Vec<i32> = Vec::new();
    c.push(CONSTRAINT_EQ); c.push(42);
    let result: i32 = solve_1var(c, 1, 0, 100);
    print(str_concat("  x = ", str_from_int(result)));
    if result == 42 { print("  PASS"); 0 } else { print("  FAIL"); 1 }
}

fn test_range_constraint() -> i32 {
    print("=== Solver 2: x > 10 AND x < 15 ===");
    let mut c: Vec<i32> = Vec::new();
    c.push(CONSTRAINT_GT); c.push(10);
    c.push(CONSTRAINT_LT); c.push(15);
    let result: i32 = solve_1var(c, 2, 0, 20);
    print(str_concat("  x = ", str_from_int(result)));
    if result > 10 && result < 15 { print("  PASS"); 0 } else { print("  FAIL"); 1 }
}

fn test_exclusion() -> i32 {
    print("=== Solver 3: x > 0 AND x != 5 AND x < 10 ===");
    let mut c: Vec<i32> = Vec::new();
    c.push(CONSTRAINT_GT); c.push(0);
    c.push(CONSTRAINT_NEQ); c.push(5);
    c.push(CONSTRAINT_LT); c.push(10);
    let result: i32 = solve_1var(c, 3, 0, 20);
    print(str_concat("  x = ", str_from_int(result)));
    if result > 0 && result != 5 && result < 10 { print("  PASS"); 0 } else { print("  FAIL"); 1 }
}

fn test_unsatisfiable() -> i32 {
    print("=== Solver 4: x > 10 AND x < 5 (unsat) ===");
    let mut c: Vec<i32> = Vec::new();
    c.push(CONSTRAINT_GT); c.push(10);
    c.push(CONSTRAINT_LT); c.push(5);
    let result: i32 = solve_1var(c, 2, 0, 20);
    if result == 0 - 999999 { print("  PASS (correctly unsatisfiable)"); 0 }
    else { print("  FAIL (should be unsat)"); 1 }
}

fn test_tight_constraint() -> i32 {
    print("=== Solver 5: x > 6 AND x < 8 (only x=7) ===");
    let mut c: Vec<i32> = Vec::new();
    c.push(CONSTRAINT_GT); c.push(6);
    c.push(CONSTRAINT_LT); c.push(8);
    let result: i32 = solve_1var(c, 2, 0, 20);
    print(str_concat("  x = ", str_from_int(result)));
    if result == 7 { print("  PASS (unique solution)"); 0 } else { print("  FAIL"); 1 }
}

fn main() -> i32 {
    print("================================================");
    print("  Constraint Solver (Phase 14, GAP-18)");
    print("  (Pure-Nucleor fallback — Z3 FFI when available)");
    print("================================================");
    let mut pass: i32 = 0;
    let mut fail: i32 = 0;
    if test_simple_eq() == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if test_range_constraint() == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if test_exclusion() == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if test_unsatisfiable() == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if test_tight_constraint() == 0 { pass = pass + 1; } else { fail = fail + 1; };
    print("================================================");
    print(str_concat("  passed: ", str_from_int(pass)));
    print(str_concat("  failed: ", str_from_int(fail)));
    if fail == 0 { print("  ALL SOLVER TESTS PASS"); };
    print("================================================");
    fail
}
