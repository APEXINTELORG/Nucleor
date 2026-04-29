// repro_v74_div_by_literal_zero.nr — v0.4.74 NUM-009.
// Pre-fix `let x: i64 = 100 / 0;` const-fold-skipped (good — see
// opt_fold_block v0.3.145) but emitted `sdiv i64 100, 0` to LLVM,
// which traps at runtime as SIGFPE (exit 127). Loud, but
// runtime-only — adopters who wrote literal `/0` (typo, refactor
// residue, dead-code branch) shipped a binary that crashed on
// first execution instead of failing the build.
//
// v0.4.74 promotes literal-zero division/remainder to NUM-009
// (already reserved in RFC-0015 / v0.2.319 expansion). Rust E0080
// does the equivalent compile-time halt.
//
// EXPECT: build fails with NUM-009 (msg contains "literal zero").

fn main() -> i64 {
    let x: i64 = 100 / 0;
    println!("{}", x);
    return 0;
}
