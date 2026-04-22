// Error test: pure function cannot acquire ambient random capability
pure fn bad() -> i32 {
    let rng: RandomCap = ambient_random();
    let _keep: RandomCap = rng;
    0
}

fn main() -> i32 {
    bad()
}
