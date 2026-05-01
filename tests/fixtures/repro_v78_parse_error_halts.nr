// repro_v78_parse_error_halts.nr — v0.4.78 NR020.
// Pre-fix `expect_tok` printed "Parse error at token position N:
// expected token X got Y" via `print()` and returned `pos + 1`,
// continuing the parse on garbage input. The downstream type-check
// + lower happily consumed the broken AST, codegen emitted a
// "successful" binary, and the user got a likely-broken executable.
// v0.4.78 promotes parse errors from print-and-recover to NR020
// panic. Closes the broadest silent-fall-through class in the
// pipeline.
//
// The original fixture used `x @ 1..=10`, which is valid after
// RFC-0023 pattern support. Keep the invariant pinned with an
// invalid `@` where a function identifier is required.
//
// EXPECT: build fails with NR020 (msg contains "parse error").

fn @broken() -> i64 {
    return 0;
}

fn main() -> i64 {
    return 0;
}
