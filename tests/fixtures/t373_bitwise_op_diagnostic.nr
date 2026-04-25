// t373_bitwise_op_diagnostic.nr — v0.3.103 positive regression fixture.
//
// Original v0.3.97 fixture pinned a diagnostic that the bitwise ops
// `&` / `|` / `^` were unsupported at expression-position. v0.3.103
// replaces that diag-only stub with real bitwise codegen via a new
// `parse_bitwise` precedence tier (between parse_eq and parse_and_expr),
// `^` lexer entry as token 94, and a new LLVM `xor i64` (iop 15)
// alongside the existing `and i64` (iop 13) and `or i64` (iop 14).
// The const folder also now applies bitwise semantics (not logical
// truthiness) to ops 13/14/15 so constant-folded and runtime paths
// produce identical answers.
//
// This fixture exercises all three ops with constant operands so
// the optimizer fold path is hit, plus a chained mixed expression
// to exercise the runtime path. Returns 0 when all answers match;
// any mismatch returns a non-zero diagnostic code.

fn main() -> i64 {
    let a: i64 = 12;       // 0b1100
    let b: i64 = 10;       // 0b1010
    if a & b != 8 { return 1; };       // 0b1000 = 8
    if a | b != 14 { return 2; };      // 0b1110 = 14
    if a ^ b != 6 { return 3; };       // 0b0110 = 6
    if (255 & 15) != 15 { return 4; }; // hex literals + const fold
    if (0xff ^ 0x0f) != 240 { return 5; };
    let c: i64 = a & b | 1;            // (12&10)|1 = 8|1 = 9
    if c != 9 { return 6; };
    return 0;
}
