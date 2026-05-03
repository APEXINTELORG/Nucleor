// v0.7.12 (defensive halt): canonical Rust stdlib smart-pointer
// types `Cell`, `RefCell`, `Rc`, `Arc`, `Mutex`, `RwLock`, `Weak`
// pre-fix surfaced via the generic v0.3.71 'unsupported associated-
// fn call' diag mentioning Vec/String/etc. — not adopter-actionable.
// None of these wrappers are needed in Nucleor's i64-everywhere ABI
// (no borrow-checker enforcement, no shared-ownership requirement
// under single-threaded default). Now halts cleanly with workaround
// pointer (use bare type with `let mut` for mutability; the i64
// ABI already passes by value for shared-ownership). Negative fixture.
fn main() -> i32 {
    let c: Cell<i64> = Cell::new(42);    // ← halts: smart-pointer unsupported
    print_int(c.get() as i32);
    return 0;
}
