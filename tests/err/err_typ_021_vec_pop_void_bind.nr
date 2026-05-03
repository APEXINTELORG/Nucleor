// EXPECT: error[TYP-021] `void`-typed expression cannot initialize binding
// err_typ_021_vec_pop_void_bind — v0.6.42 negative fixture
// closes probe finding 2026-04-30-vec-pop-void-coerce-to-zero.
// Pre-fix `let x = vec_pop(v)` silently bound 0 — vec_pop is a
// void-returning runtime helper but type_expr's vec-read-call
// path returned the Vec's element type, treating it as a value-
// returning Rust-like helper. Adopters got a 0-valued binding
// indistinguishable from a popped 0. v0.6.42 overrides init_t to
// "void" when the let RHS is a direct kind-7 call to vec_pop, so
// TYP-021 fires.
//
// EXPECT: TYP-021 fires; build halts.

fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    let x = vec_pop(v);
    print_int(x as i32);
    0
}
