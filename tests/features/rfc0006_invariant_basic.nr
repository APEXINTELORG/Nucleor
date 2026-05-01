// RFC-0006 Design by Contract — `#[invariant(EXPR)]` on impl
// blocks, runtime check at method entry.
//
// v0.4.248: source-text scanner finds `#[invariant(EXPR)] impl
// <Type> { ... }` (and the trait-impl variant `impl <Trait> for
// <Type>`) and stores the predicate by type name. Pre-pass
// lex+parses each predicate into the AST pool. lower_fn extracts
// the type prefix from the mangled method name (`Type__method`
// split on `__`), looks up the type's invariant, and emits
// `__nucleor_contract_invariant(predicate)` at method entry —
// only for methods where the first param is named `self`.
//
// EXPECT: build success, runtime exit 0, output "OK rfc0006_invariant_basic".

struct Counter { value: i64 }

#[invariant(self.value >= 0)]
impl Counter {
    fn get(self: Counter) -> i64 {
        self.value
    }
    fn doubled(self: Counter) -> i64 {
        self.value * 2
    }
}

fn main() -> i64 {
    let a: Counter = Counter { value: 0 };
    let av: i64 = a.get();
    if av != 0 { print("FAIL get(0)"); return 1; };

    let b: Counter = Counter { value: 7 };
    let bv: i64 = b.get();
    if bv != 7 { print("FAIL get(7)"); return 1; };

    let bd: i64 = b.doubled();
    if bd != 14 { print("FAIL doubled(7)"); return 1; };

    let c: Counter = Counter { value: 100 };
    let cd: i64 = c.doubled();
    if cd != 200 { print("FAIL doubled(100)"); return 1; };

    print("OK rfc0006_invariant_basic");
    0
}
