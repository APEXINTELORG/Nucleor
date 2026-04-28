// repro_v66_mixed_str_int_arith_guard.nr
//
// v0.4.66 NUC-FEEDBACK silent-coerce close for mixed-type
// arithmetic involving str. Pre-fix `x + "string"` (and `x +=
// "string"` which desugars to it) with `x: i64` silently
// i64-added the str pointer to x, producing garbage. Adopters
// writing canonical Rust got a quiet wrong value (Rust errors
// with E0277 — `Add` not implemented).
//
// v0.4.66 catches arith ops 20-24 with exactly ONE side being str
// (the v0.4.51 close required BOTH; mixed-type hazard was open).

fn main() -> i64 {
    let mut x: i64 = 10;
    x += "string";   // TYP-011 expected (mixed i64 + str)
    println!("{}", x);
    return 0;
}
