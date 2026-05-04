// v0.7.47 negative fixture — local type alias `type Foo = Bar;` inside
// a fn body. Pre-fix: wrong-class `error[NR020]: parse_primary cannot
// start an expression at token kind 74`. Post-fix: clean halt with
// hoist-to-module-scope workaround pointer.
//
// Workaround: place the alias at module scope:
//   type Pair = (i64, i64);
//   fn use_pair() -> i64 { ... }
fn main() -> i64 {
    type Pair = (i64, i64);
    return 0;
}
