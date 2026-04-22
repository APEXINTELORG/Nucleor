// panic_builtin.nr — RFC-0016 partial: panic() builtin
// Calls __nucleor_panic which prints message + exits 1.
// We test the success path here (no actual panic). For runtime-trap
// behavior tests, use a #[should_panic] test.

fn maybe_panic(should: i64, msg: str) -> i64 {
    if should == 1 { panic(msg); };
    return 0;
}

fn main() -> i32 {
    let r1: i64 = maybe_panic(0, "this should not fire");
    if r1 != 0 { print("FAIL: maybe_panic 0 returned non-zero\n"); return 1; };
    print("OK panic_builtin\n");
    return 0;
}
