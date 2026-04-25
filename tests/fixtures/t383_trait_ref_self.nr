// t383_trait_ref_self.nr — v0.3.106 regression fixture.
//
// Pins `&self` / `&mut self` in trait method declarations.
// Pre-v0.3.106, parse_trait_decl only recognized bare `self` (used
// in older fixtures), so the canonical Rust form `fn say(&self)`
// cascaded into 13+ parse errors as the param-loop tried to
// consume `&` as a param name and then `self` as a comma-separated
// next param. Empty impl blocks `impl Trait for Foo {}` (relying
// on default trait methods) were collateral damage — they triggered
// the same trait declaration which never parsed.
//
// Fix: mirror the parse_impl_block `&self` branch in
// parse_trait_decl, producing a `&Self` / `&mut Self` advisory
// type for the receiver param.
//
// Returns 1 (the default trait method body's value) when the empty
// impl correctly inherits the default method.

trait Greet {
    fn say(&self) -> i64 { return 1; }
}

struct Foo {}

impl Greet for Foo {}

fn main() -> i64 {
    let f: Foo = Foo {};
    return f.say();
}
