// t361_assoc_const_diagnostic.nr — v0.3.85 negative regression fixture.
//
// Pre-v0.3.85, writing `const NAME: T;` in a trait body or
// `const NAME: T = V;` in an impl body cascaded into 18+ parse
// errors as the body parser expected `fn` and got `const`.
// Recovery walked into the rest of the body mis-aligned.
//
// Post-v0.3.85: clean diagnostic in both parse_trait_decl and
// parse_impl_block, recovery skips to the next stmt boundary.

trait HasMax { const MAX: i64; }

#[repr(C)]
struct Counter { n: i64 }

impl HasMax for Counter { const MAX: i64 = 100; }

fn main() -> i64 {
    return 0;
}
