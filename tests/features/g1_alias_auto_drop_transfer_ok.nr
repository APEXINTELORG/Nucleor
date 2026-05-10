// RFC-0062 G-1: typed collection aliasing transfers the auto-drop
// cleanup obligation. Pre-fix, `v` stayed registered for generated
// cleanup after `let alias: Vec<i64> = v`, so explicit freeing of
// `alias` could be followed by a generated `vec_free(v)`.
fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    vec_push(v, 1);
    let alias: Vec<i64> = v;
    vec_free(alias);
    0
}
