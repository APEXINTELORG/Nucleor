// repro_v77_neg_to_unsigned.nr — v0.4.77 NUM-019.
// Pre-fix `let x: u32 = -5;` two's-complement-wrapped to
// 4294967291 silently (the LLVM `i64 -5` truncates to u32::MAX-4
// when stored in a 32-bit slot). Adopters writing canonical Rust
// got E0080 (overflowing_literals in debug; wrapping in release).
//
// v0.4.77 promotes negative-literal-in-unsigned-binding to NUM-019
// (already reserved in RFC-0015 / v0.2.319 expansion). Detection:
// init is unary-minus AST (kind 5) wrapping a positive int literal
// (kind 1) — `let x: u32 = 0;` and `let x: i32 = -5;` both stay ok.
//
// EXPECT: build fails with NUM-019 (msg contains "negative literal").

fn main() -> i64 {
    let x: u32 = -5;
    println!("{}", x);
    return 0;
}
