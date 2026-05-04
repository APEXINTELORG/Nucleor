// v0.7.13 (defensive halt): canonical Rust trait alias
// `trait Pretty = Show;` (RFC 1733, nightly-only in Rust today)
// pre-fix surfaced as wrong-class `NR020: expected '{', got '='`
// because parse_trait_decl had no `=` branch. Now halts cleanly
// with a "use a regular trait with supertraits" workaround
// pointer. Negative fixture (compile rejects).
trait Show {
    fn show(self: &Self) -> str;
}

trait Pretty = Show;    // ← halts: trait alias unsupported

fn main() -> i32 {
    print_int(0);
    return 0;
}
