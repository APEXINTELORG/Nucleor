// t380_shift_ops.nr — v0.3.104 regression fixture.
//
// Pins shift-left `<<` and shift-right `>>` codegen. Pre-v0.3.104,
// the lexer emitted neither token, so `let y: i64 = x << 4;` and
// `return x >> 4;` parsed as `x` alone followed by garbage that
// was silently dropped — silent miscompute returning whatever the
// LHS happened to be (or 0 from optimizer dead-store, depending on
// position). Same hazard class as the v0.3.103 bitwise fix:
// HIGH-blast for any low-level work doing shifts (mask building,
// pack/unpack, hash mixing, fast division-by-power-of-two).
//
// Implementation:
//   - Lexer: `<<` → token 115. `>>` is NOT a single token (avoids
//     breaking generics like `Vec<Vec<i64>>` whose final `>>` is
//     two angle closes). parse_shift detects two adjacent `>` tokens
//     and synthesizes a virtual `>>` op (kind 116) at AST mk-time.
//   - Parser: new `parse_shift` tier between parse_add and
//     parse_bitwise so `1 << 4 + 2` parses as `1 << (4 + 2)` (`+`
//     binds tighter), and `a & b << c` parses as `a & (b << c)`.
//   - tok_to_ir: 115 → iop 23 (LLVM `shl i64`); 116 → iop 24 (LLVM
//     `ashr i64`, signed/arithmetic right shift).
//   - emit_inst: ops 23/24 emit shl/ashr.
//   - DCE + opt_fold: ops 23/24 added to pure-op range.
//
// Returns 0 when both shifts produce the right answer; non-zero
// diagnostic codes pinpoint which op miscomputed.

fn main() -> i64 {
    if (1 << 4) != 16 { return 1; };
    if (256 >> 4) != 16 { return 2; };
    let a: i64 = 3;
    let b: i64 = 2;
    if (a << b) != 12 { return 3; };
    if (16 >> 2) != 4 { return 4; };
    // Precedence: shift > bitwise. `a & 0xff << 1` should be
    // `a & (0xff << 1)` = `3 & 510` = `2` (bit 1 only).
    if (a & 0xff << 1) != 2 { return 5; };
    return 0;
}
