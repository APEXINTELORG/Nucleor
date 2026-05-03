// v0.6.99 (defensive halt): canonical Rust associated types in
// traits (`type Item;`, `type Item = i64;`) pre-fix surfaced as
// wrong-class `NR020: expected token 10 (fn), got token 74 (type)`
// because parse_trait_decl's body loop only knows fn decls. Now
// halts cleanly with a generic-param workaround pointer.
// Negative fixture (compile rejects).
trait Container {
    type Item;    // ← halts: associated type unsupported
    fn get(self: &Self) -> Self::Item;
}

fn main() -> i32 {
    print_int(0);
    return 0;
}
