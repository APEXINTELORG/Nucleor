// repro_v99_parse_primary_narrow_panic.nr — v0.4.99 §_p (audit doc-#1).
// Pre-fix `parse_primary` fall-through silently returned int_lit(0)
// for ALL unhandled tokens. v0.4.99 narrows the silent fallback to
// only recovery-context markers (`)` `,` `;` `}` `]` `=` `EOF`).
// Anything else panics with NR020 + token kind + byte position.
//
// pgs_smoke's legitimate macro-expanded `)` at byte 6571 still
// works (token 51 is in the recovery-marker set).
//
// This fixture uses `@` binding pattern which is not yet parsed
// — pre-v0.4.78 it printed "Parse error" + continued; v0.4.78
// expect_tok NR020 panicked at the inner expect_tok before
// parse_primary fall-through. Both panics are valid silent-
// miscompute closes.
//
// EXPECT: build fails (msg contains "NR020").

fn main() -> i64 {
    let n: i64 = 5;
    let s: str = match n {
        x @ 1..=10 => "small",
        _ => "big",
    };
    println!("{}", s);
    return 0;
}
