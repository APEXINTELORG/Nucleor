// t411_user_fn_named_pure.nr — v0.3.137 regression fixture.
//
// Pins user fns and call sites named `pure`. Pre-v0.3.137, `pure`
// was classified as a hard keyword (token 68) by the lexer because
// `pure fn name(...)` is the canonical effect annotation. The
// annotation is rare; the identifier collision is not. Any adopter
// who happened to name a fn `pure` (a common name for math /
// utility / parser / functional helpers) hit the trap:
//
//   1. `fn pure(x) { ... }` — lexer produced `[fn, pure(68), (, x, ...)]`.
//      parse_fn_decl read pkv at the kw position and got the string
//      "pure", so the fn was registered under the right name.
//   2. `pure(0)` at the call site — the `pure` keyword token landed
//      at parse_primary, which had no branch for it. Silent
//      fall-through to the `int_lit 0` default at the bottom of
//      parse_primary. The call collapsed to a constant 0 and the
//      remaining `(0)` produced a downstream parse error that the
//      caller ignored.
//
// Same hazard class as the v0.3.126 user-fn-shadows-runtime bug
// (silent dispatch failure under what looks like the right name)
// and the v0.3.130 long-f64 / v0.3.133 sub-micro-f64 silent zeros.
//
// Fix (v0.3.137): make `pure` a contextual keyword. classify_kw no
// longer maps it to 68; the `pure fn` declaration form is recognised
// at parse_program by checking `pkv == "pure" && next == fn`. The
// identifier path in parse_primary handles call sites normally.
//
// Returns 42 = pure(41) = 41 + 1, proving the call dispatched to the
// user fn instead of being eliminated to const 0.

fn pure(x: i64) -> i64 { return x + 1; }

fn main() -> i64 {
    let r: i64 = pure(41);
    return r;
}
