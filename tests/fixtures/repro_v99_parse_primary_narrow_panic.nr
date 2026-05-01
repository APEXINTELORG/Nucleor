// repro_v99_parse_primary_narrow_panic.nr — v0.4.99 §_p (audit doc-#1).
// Pre-fix `parse_primary` fall-through silently returned int_lit(0)
// for ALL unhandled tokens. v0.4.99 narrows the silent fallback to
// only recovery-context markers (`)` `,` `;` `}` `]` `=` `EOF`).
// Anything else panics with NR020 + token kind + byte position.
//
// pgs_smoke's legitimate macro-expanded `)` at byte 6571 still
// works (token 51 is in the recovery-marker set).
//
// The original fixture used `@` binding pattern, which is valid
// after RFC-0023 pattern support. Keep the parse_primary narrow-
// panic invariant pinned with `@` in expression position.
//
// EXPECT: build fails (msg contains "NR020").

fn main() -> i64 {
    let n: i64 = @;
    return n;
}
