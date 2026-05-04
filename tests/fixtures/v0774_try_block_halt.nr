// v0.7.74 negative fixture — Rust experimental `try { ... }` block.
// Pre-fix `let r: i64 = try { ... };` produced wrong-class
// `error[TYP-005]: undefined function 'try()'` at clang link
// because parse_primary read `try` as an ident and `{ ... }` as
// stray block, so the surface treated it as a fn call. Now halts
// at parse_primary when `try` is followed by `{`.
fn main() -> i64 {
    let r: i64 = try {
        let x: i64 = 5;
        x
    };
    return r;
}
