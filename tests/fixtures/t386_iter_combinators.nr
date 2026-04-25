// t386_iter_combinators.nr — v0.3.109 regression fixture.
//
// Pins the `.iter().any(p)` / `.all(p)` / `.take(n)` / `.skip(n)`
// iterator combinators. Pre-v0.3.109, none of these names were in
// `iter_method_for_vec` so kind-8 dispatch fell through to the
// `vec_<method>` convention — clang link unresolved (`@vec_take
// undefined` etc.) for any user reaching for these canonical Rust
// iterator methods. The `any`/`all` runtime helpers were already
// present (added in v0.2.x); v0.3.109 adds `take_i64` / `skip_i64`
// new helpers + the four-method dispatch wiring.
//
// Returns 0 when all four combinators produce the right answer;
// non-zero diagnostic codes pinpoint which one miscomputed.

fn gt5(x: i64) -> i64 { if x > 5 { return 1; }; return 0; }
fn pos(x: i64) -> i64 { if x > 0 { return 1; }; return 0; }

fn main() -> i64 {
    let v: Vec<i64> = vec![1, 2, 3, 4, 5, 6];
    if v.iter().any(gt5) != 1 { return 1; };

    let p: Vec<i64> = vec![1, 2, 3];
    if p.iter().all(pos) != 1 { return 2; };

    let t: Vec<i64> = vec![10, 20, 30, 40, 50];
    if t.iter().take(3).sum() != 60 { return 3; };

    let s: Vec<i64> = vec![10, 20, 30, 40];
    if s.iter().skip(2).sum() != 70 { return 4; };

    return 0;
}
