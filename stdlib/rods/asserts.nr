// =====================================================
// rods/asserts — Assertion + debug helpers (RFC-0021)
// =====================================================
// Import: import "stdlib/rods/asserts.nr"
//
// Wraps the v0.1.14/v0.1.15/v0.1.25 assert!/dbg!/panic! builtins.
// =====================================================

// ---- Assertion ----
fn check(cond: i64) -> i64 { return assert(cond); }
fn check_eq(a: i64, b: i64) -> i64 { return assert_eq(a, b); }
fn check_ne(a: i64, b: i64) -> i64 { return assert_ne(a, b); }

// ---- Panic ----
fn fail(msg: str) -> i64 { return panic(msg); }

// ---- Debug print (returns the value untouched) ----
fn debug_int(v: i64) -> i64 { return dbg(v); }
fn debug_str(s: str) -> i64 { return dbg_str(s); }

// ---- Stderr output ----
fn err_print(s: str) -> i64 { return eprint(s); }
fn err_print_int(n: i64) -> i64 { return eprint_int(n); }

// ---- Convenience: bounded check with custom message ----
fn check_with(cond: i64, msg: str) -> i64 {
    if cond == 0 { return panic(msg); };
    return 0;
}
