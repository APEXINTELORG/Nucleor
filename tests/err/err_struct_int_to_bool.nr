// EXPECT: error[TYP-008] declared `bool`, got int literal
// v0.4.133: extends v0.4.84 struct-field literal-RHS type check
// to catch int-literal initialization of bool-typed fields. Pre-fix
// `P { x: 5 }` for `x: bool` silently stored 5 as i64; reads of
// p.x then evaluated truthy (5 != 0) but adopters lost the type
// guarantee. Rust E0308. Also suggests `true`/`false` instead.

struct P { x: bool }

fn main() -> i32 {
    let p: P = P { x: 5 };
    if p.x { print("t"); } else { print("f"); }
    0
}
