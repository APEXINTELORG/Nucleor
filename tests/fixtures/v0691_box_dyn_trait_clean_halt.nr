// v0.6.91 (defensive halt): canonical Rust `Box<dyn Trait>`
// polymorphism dispatch — `let d: Box<dyn Animal> = Box::new(Dog{});
// d.speak();` pre-fix fell through every typed-receiver branch and
// the kind-8 catch-all synthesized `vec_speak(receiver)`, surfacing
// as wrong-class TYP-005 'Vec<T> has no method'. Trait-object
// dispatch needs a vtable; Nucleor's i64-everywhere ABI doesn't yet
// have one. Now halts cleanly with workaround pointer (concrete
// type or enum-dispatch wrapper). Negative fixture (compile rejects).
trait Animal {
    fn speak(self: &Self) -> str;
}

struct Dog;
impl Animal for Dog {
    fn speak(self: &Dog) -> str { return "woof"; }
}

fn main() -> i32 {
    let d: Box<dyn Animal> = Box::new(Dog {});
    print(d.speak());     // ← halts: trait-object dispatch unsupported
    return 0;
}
