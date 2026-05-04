// EXPECT: `#[inline]` / `#[inline(always)]` attributes are not yet supported
// Q10 lock-in — v0.8.22. Inline / cold attribute hints halt
// cleanly today; the optimizer makes its own inline decisions.
// Tracked for forward-roadmap (attribute-driven inliner hints).

#[inline]
fn add(a: i64, b: i64) -> i64 { return a + b; }

fn main() -> i64 {
    return add(1, 2);
}
