// v0.6.81 RFC V1.7: UFCS dispatch `<Type as Trait>::method(args)`.
// Pre-fix the `<` at expression start panicked with the v0.6.60
// halt + workaround pointer. Now parsed and routed to the type-
// mangled name `<Type>__<method>` (Nucleor's existing trait-impl
// mangling — per-trait disambiguation is the v1.x trait-dispatch
// ship).
trait Greet {
    fn hello(self: &Self) -> str;
}

struct W { v: i64 }

impl Greet for W {
    fn hello(self: &W) -> str { return "hi from W"; }
}

fn main() -> i32 {
    let w: W = W { v: 7 };
    // UFCS form — verbose surface alias for w.hello()
    print(<W as Greet>::hello(&w));
    return 0;
}
