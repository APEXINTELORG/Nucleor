// RFC-0006 Design by Contract — `#[invariant(EXPR)]` on
// constructor methods.
//
// v0.4.253: invariant emit at fn EXIT for constructors. A
// constructor is an impl-block fn whose first param is NOT
// `self` AND whose return type matches the parent type (or is
// `Self`). At fn-entry, the invariant CAN'T be checked (no
// instance exists yet); the predicate runs at fn-exit on the
// just-constructed value, with `self` bound to the rv.
//
// EXPECT: build success, runtime exit 0, output "OK rfc0006_invariant_ctor".

struct Counter { value: i64 }

#[invariant(self.value >= 0)]
impl Counter {
    fn new(initial: i64) -> Counter {
        Counter { value: initial }
    }
    fn from_doubled(x: i64) -> Counter {
        Counter { value: x + x }
    }
    fn get(self: Counter) -> i64 {
        self.value
    }
}

fn main() -> i64 {
    let a: Counter = Counter::new(0);
    let av: i64 = a.get();
    if av != 0 { print("FAIL new(0)"); return 1; };

    let b: Counter = Counter::new(42);
    let bv: i64 = b.get();
    if bv != 42 { print("FAIL new(42)"); return 1; };

    let c: Counter = Counter::from_doubled(7);
    let cv: i64 = c.get();
    if cv != 14 { print("FAIL from_doubled(7)"); return 1; };

    print("OK rfc0006_invariant_ctor");
    0
}
