// v0.4.36 silent-fall-through closure: `Foo { x: 1 }` where Foo is
// undeclared used to lower to `lx_new(-1, blk)` → `%r.-1` invalid IR.
// Clang caught it but with a confusing "use of undefined value" error
// pointing at LLVM IR, not source. Now panics at compiler level.
// EXPECT: panic
fn main() -> i64 {
    // `UndeclaredStruct` was never declared; pre-fix produced %r.-1
    let p = UndeclaredStruct { x: 1, y: 2 };
    return p.x;
}
