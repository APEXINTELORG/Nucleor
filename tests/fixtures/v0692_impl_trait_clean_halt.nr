// v0.6.92 (defensive halt): canonical Rust `impl Trait` type
// position (return-position or argument-position trait-bound sugar)
// pre-fix surfaced as wrong-class `error[NR020]: expected '{', got
// identifier` because parse_type had no `impl` branch — the outer
// fn-decl parser saw `impl Iterator<...>` after `->` and expected
// the body's `{`. Now halts cleanly with a workaround pointer.
// Negative fixture (compile rejects). Sister to v0.6.91 Box<dyn>
// halt — both await the v1.x trait-object substrate.
fn make_iter() -> impl Iterator<Item = i64> {
    let v: Vec<i64> = [1, 2, 3];
    return v.iter();
}

fn main() -> i32 {
    let it = make_iter();    // ← halts: impl Trait unsupported
    print_int(0);
    return 0;
}
