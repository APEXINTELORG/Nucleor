// t355_nested_field_assign_diagnostic.nr — v0.3.80 negative regression fixture.
//
// Pre-v0.3.80, writing `outer.inner.field = X;` segfaulted the
// compiler with ACCESS_VIOLATION (exit -1073741819) during the
// ownership/type check pass. v0.3.80 detects nested kind-9 LHS in
// check_stmt's kind-21 (assign) handler and emits a clear diagnostic
// pointing at the workaround instead of crashing.
//
// This fixture is intended to FAIL compilation cleanly (no segfault).
// The verify step asserts: (1) build does NOT segfault (exit code is
// not -1073741819), (2) the diagnostic text appears in stderr.
//
// The actual nested-mutation feature (get-modify-set lowering) is
// tracked for a future ship. For now, the workaround pattern of
// copy → mutate → assign-back is the canonical idiom and is verified
// by the workaround sub-pattern in this fixture's accompanying probe.

#[repr(C)]
struct Inner { val: i64 }

#[repr(C)]
struct Outer { inner: Inner, count: i64 }

fn main() -> i64 {
    let mut o: Outer = Outer { inner: Inner { val: 5 }, count: 10 };
    o.inner.val = 99;     // <-- pre-v0.3.80: segfault, post: clean diagnostic
    return o.inner.val;
}
