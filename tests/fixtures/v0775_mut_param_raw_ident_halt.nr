// v0.7.75 consolidated negative fixture — two halt points share
// the same wrong-class-rust-syntax-fidelity pattern:
//   - `mut` qualifier on fn parameter (`fn inc(mut x: i64)`)
//   - raw identifier prefix `r#name` (lex-time, e.g. `let r#type: i64 = 42;`)
//
// To validate the raw-ident form, swap the body for
//   `let r#type: i64 = 42; return r#type;`
// (note the surface diag for r#type before v0.7.75 was the v0.7.47
// local-type-alias halt — the r#-prefix is what changed; the second
// part of the sequence still hit the type-alias path as a side
// effect because `type` is a Nucleor keyword.)
fn inc(mut x: i64) -> i64 {
    x = x + 1;
    return x;
}

fn main() -> i64 {
    return inc(10);
}
