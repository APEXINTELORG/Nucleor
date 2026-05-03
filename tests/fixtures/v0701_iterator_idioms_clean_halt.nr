// v0.7.1 (defensive halt extension): canonical Rust iterator
// adapter idioms `.rev()`, `.enumerate()`, `.zip()`, `.windows()`,
// `.chunks()`, `.flat_map()`, `.flatten()`, `.peekable()`,
// `.fuse()` pre-fix fell through to the kind-8 catch-all
// `vec_<idiom>(receiver)`, surfacing as wrong-class TYP-005
// 'Vec<T> has no method'. Now halt cleanly with per-idiom
// index-based-loop workaround pointers. Sister to v0.6.82
// conversion-idiom halts. Negative fixture (compile rejects).
fn main() -> i32 {
    let v: Vec<i64> = [1, 2, 3];
    for x in v.iter().rev() {    // ← halts: .rev() not yet supported
        print_int(x as i32);
    }
    return 0;
}
