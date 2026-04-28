// v0.4.33b silent-fall-through closure: associated constants in trait
// bodies. Pre-fix: ERROR printed, const decl silently dropped from
// trait surface. Post-fix: panic.
// EXPECT: panic
trait MyTrait {
    const MAX: i64;
    fn run(&self) -> i64;
}

fn main() -> i64 { return 0; }
