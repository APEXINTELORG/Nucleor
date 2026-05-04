// v0.8.8 Phase B step-1 — core Nucleor attribute audit smoke
// fixture. Extends the discovery surface from the V2 frontier
// attributes (v0.8.5/6/7) to existing core attrs adopters use
// today: @hot, @const_fn, #[max_depth], #[deadline].
//
// Build emits four audit summary lines:
//   audit: @hot fns in build: 1
//   audit: @const_fn fns in build: 1
//   audit: #[max_depth] fns in build: 1
//   audit: #[deadline] fns in build: 1
// rc = 4 (one fn per family, each returns 1).

@hot
fn hot_loop() -> i64 { return 1; }

@const_fn
fn ct_eligible() -> i64 { return 1; }

#[max_depth = 8]
fn bounded() -> i64 { return 1; }

#[deadline = 1000]
fn timed() -> i64 { return 1; }

fn main() -> i64 {
    return hot_loop() + ct_eligible() + bounded() + timed();
}
