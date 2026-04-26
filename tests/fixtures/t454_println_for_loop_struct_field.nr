// t454_println_for_loop_struct_field.nr -- v0.3.188 regression
// fixture.
//
// Sister fix to v0.3.166 (println! struct field heuristic) and
// v0.3.175 (for-loop var type registration).
//
// Pre-v0.3.188, `for s in stats.iter() { println!("{} = {}",
// s.name, s.mean) }` printed pointer addresses for s.name and
// s.mean even though Stats is `{ name: str, mean: f64, ... }`.
// The println! `{}` heuristic detected the `<recv>.<field>`
// shape but `infer_var_type_from_source` only knew about
// `let X: TYPE` declarations -- not for-loop bindings.
//
// Same hazard class as v0.3.166/167/172 -- adopters writing
// canonical iterate-and-print patterns get pointer addresses
// with no diagnostic.
//
// Fix (v0.3.188): extend `infer_var_type_from_source` to also
// recognize `for <var_name> in <iter_expr>` patterns. When
// found, recurse on the iter expression to derive the
// receiver's full type, then strip one container layer
// (Vec<T> -> T). Also strips trailing `.iter()` / `.into_iter()`
// from the iter expression.

struct Stat { name: str, mean: f64, count: i64 }

fn main() -> i64 {
    let mut stats: Vec<Stat> = Vec::new();
    stats.push(Stat { name: "alpha", mean: 3.14, count: 100 });
    stats.push(Stat { name: "beta", mean: 2.71, count: 200 });

    for s in stats.iter() {
        println!("{} = {} (n={})", s.name, s.mean, s.count);
    }

    return 42;
}
