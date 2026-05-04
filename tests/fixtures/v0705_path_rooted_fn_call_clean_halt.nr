// v0.7.5 (defensive halt): canonical Rust path-rooted fn calls
// `crate::foo(...)`, `super::foo(...)`, `self::foo(...)` pre-fix
// surfaced via the generic v0.3.71 'unsupported associated-fn
// call' diag mentioning only Vec/String/etc. — not adopter-
// actionable for the path case. Now halts cleanly with a
// "drop the path prefix" workaround pointer (Nucleor has a flat
// fn namespace today; the resolved fn name is callable directly).
// Negative fixture (compile rejects). Sister to v0.6.96 std/core/
// alloc namespace path halt.
fn helper(x: i64) -> i64 { return x * 2; }

fn main() -> i32 {
    let v: i64 = crate::helper(5);    // ← halts: path-rooted fn call unsupported
    print_int(v as i32);
    return 0;
}
