// repro_v78_parse_error_halts.nr — v0.4.78 NR020.
// Pre-fix `expect_tok` printed "Parse error at token position N:
// expected token X got Y" via `print()` and returned `pos + 1`,
// continuing the parse on garbage input. The downstream type-check
// + lower happily consumed the broken AST, codegen emitted a
// "successful" binary, and the user got a likely-broken executable.
// Triaged this cycle via the `@` binding pattern probe
// (`x @ 1..=10`) which printed the parse error AND ran to exit=0
// with no output. The previously-passing `tests/features/
// trait_bounds.nr` was also relying on this silent recovery — it
// was moved to `_unimplemented/` so the gate stays green.
//
// v0.4.78 promotes parse errors from print-and-recover to NR020
// panic. Closes the broadest silent-fall-through class in the
// pipeline.
//
// EXPECT: build fails with NR020 (msg contains "parse error").

fn main() -> i64 {
    let n: i64 = 5;
    let s: str = match n {
        x @ 1..=10 => "small",
        _ => "big",
    };
    println!("{}", s);
    return 0;
}
