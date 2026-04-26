// t439_println_method_call_dispatch.nr -- v0.3.172 regression
// fixture.
//
// Pre-v0.3.172, the println! `{}` heuristic recognized fn-call
// shape `<ident>(...)` (v0.3.158) but NOT method-call shape
// `<recv>.<method>(...)`. So `println!("{}", s.total())` where
// total() returns f64 silently printed the bit pattern via
// int_to_str (e.g. "4614253070214989087" instead of "3.14").
//
// Same hazard class as the rest of the format-heuristic chain
// (v0.3.131/152/158/166/167/169) -- a real expression you wrote
// produces nonsense output with no diagnostic.
//
// Fix (v0.3.172): when the head fails the bare-ident check
// (because it has a dot), try splitting on the last dot to
// extract receiver and method. If both are bare idents, look
// up the method return type via the existing helper.
//
// Also adds a builtin-fallback for method names like is_empty,
// contains, contains_key (always bool).

struct Stats { sum: f64 }
impl Stats {
    fn total(self) -> f64 { return self.sum; }
}

fn main() -> i64 {
    let s: Stats = Stats { sum: 3.14 };
    println!("total={}", s.total());     // pre-fix: bit pattern
    return 42;
}
