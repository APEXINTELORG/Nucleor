// v0.8.293 R09-D4 Phase 1 — @const_fn purity smoke (positive case).
//
// Per audit `BUILD_PLAN_R09_numeric_correctness.md` §1 R09-D4
// (CRITICAL): pre-v0.8.293 @const_fn was silently ignored. Now
// the s1 compiler enforces purity: an effectful body fails with
// error[NUM-009].
//
// This fixture is the POSITIVE case: a `@const_fn` doing pure
// arithmetic compiles cleanly. The companion negative fixture is
// `tests/err/err_const_fn_effectful.nr`.
//
// Phase 2 will actually evaluate the body at compile time and
// fold the result; today the body still runs at runtime — but
// the purity contract is enforced at build.
//
// Expected: rc=0; print "ok".

@const_fn
fn add_squares(x: i32, y: i32) -> i32 {
    let xs: i32 = x * x;
    let ys: i32 = y * y;
    return xs + ys;
}

fn main() -> i32 {
    let r: i32 = add_squares(3, 4);
    if r == 25 {
        print("ok");
    } else {
        print("bad");
    };
    return 0;
}
