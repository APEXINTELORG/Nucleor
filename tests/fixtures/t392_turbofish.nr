// t392_turbofish.nr — v0.3.115 regression fixture.
//
// Pins the turbofish syntax `name::<TypeArgs>(args)`. Pre-v0.3.115,
// the `::<` after the function name was treated as a regular
// `::ident` qualified-path lookup — qname captured the `<` token's
// value (garbage), the following `(` failed to match the kind-12
// dispatch shape, and the call lowered as an associated-fn-call
// with a bogus qname. The kind-12 fallback path emitted an
// informational diagnostic AND a const_int 0 — silent miscompute
// for adopters reaching for the canonical Rust generic-call form.
//
// Fix: in parse_primary, after the IDENT, detect the `::<…>(…)`
// shape (token 46 followed by token 32). Skip the angle group via
// skip_angle_group and dispatch the args through the regular
// fn-call path. Type args are advisory at lower-time anyway since
// Nucleor's monomorphic dispatch resolves at impl time.
//
// Returns 42 from `ident::<i64>(42)`, proving the type args are
// stripped and the call lowers to a normal i64 fn invocation.

fn ident<T>(x: T) -> T { return x; }

fn main() -> i64 {
    return ident::<i64>(42);
}
