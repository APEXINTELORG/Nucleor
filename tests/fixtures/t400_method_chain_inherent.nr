// t400_method_chain_inherent.nr — v0.3.123 regression fixture.
//
// Pins chained inherent-method calls. Pre-v0.3.123,
// `Counter::new().add(10).add(5)` failed at clang link with
// `@vec_add undefined`. Two related gaps:
//
//   1. `expr_struct_type` had no `kind == 12` branch — it returned
//      "" for `Counter::new()` (associated-fn-call) receivers, so
//      the kind-8 `.add(10)` couldn't see the receiver type.
//   2. The kind-8 dispatch fallback was always `vec_<method>` for
//      unknown receiver types — even when a registered impl method
//      `Counter__add` existed.
//
// Fix mirrors the v0.3.111 pattern (which fixed `Type::method()`
// dispatch for kind-12 calls themselves) into the receiver-type
// resolution AND the kind-8 user-method fallback. Both halves
// land together.
//
// Returns 15 = 0 + 10 + 5, proving each step in the chain
// dispatches to `Counter__add` (not `vec_add`) and the result
// flows through.

struct Counter { count: i64 }

impl Counter {
    fn new() -> Self { return Counter { count: 0 }; }
    fn add(self, n: i64) -> Counter { return Counter { count: self.count + n }; }
}

fn main() -> i64 {
    let c: Counter = Counter::new().add(10).add(5);
    return c.count;
}
