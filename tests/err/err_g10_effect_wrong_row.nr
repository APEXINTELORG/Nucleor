// EXPECT: EFFECT-G10-WRONG-ROW declares effect `frees`
// RFC-0062 G-10 Phase 2b — negative fixture for the WRONG-ROW
// arm. The fn declares `#[effect(frees)]` but the body never
// calls a leaf-builtin that frees, nor does it call any other
// fn with a declared `frees` effect. The declared row is wrong
// (over-declared) and the framework must emit EFFECT-G10-WRONG-ROW.

#[effect(frees)]
fn over_declared(x: i32) -> i32 {
    return x + 1;
}

fn main() -> i32 {
    over_declared(7);
    0
}
