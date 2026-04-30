// repro_v206_match_float_scrutinee_halts.nr — v0.4.206 MATCH-013.
//
// Pre-fix the compiler crashed with ACCESS_VIOLATION (Windows
// -1073741819 / SIGSEGV; no diagnostic, no .ll file emitted) when
// asked to compile a `match` over an f64 scrutinee with a
// float-literal arm. The parser fell through to the wildcard
// branch which assigned `binding` to the i64 bit-pattern of the
// float-lit token; a downstream str op then dereferenced that
// integer as a heap address. Compiler-meltdown class.
//
// Fix: parse_match_one_pattern at line 933 rejects float-lit
// pattern tokens (70, 124, 125) at parse time with a clean
// MATCH-013 panic. The type-check at kind 38 (line 12642) also
// rejects float-typed scrutinees so a wildcard-only match on a
// float still fails clean.
//
// EXPECT: build fails with MATCH-013.

fn main() -> i32 {
    let x: f64 = 1.5;
    let r: i32 = match x {
        1.5 => 100,
        _ => 0,
    };
    print_int(r);
    0
}
