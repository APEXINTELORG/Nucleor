// EXPECT: link error (false-positive negative test)
// compiler should fire pure-vs-effect; actually link-fails on __nucleor_ambient_random v0.4 placeholder. v0.2.87 finding; v0.4 will tighten.
// Error test: pure function cannot acquire ambient random capability
pure fn bad() -> i32 {
    let rng: RandomCap = ambient_random();
    let _keep: RandomCap = rng;
    0
}

fn main() -> i32 {
    bad()
}
