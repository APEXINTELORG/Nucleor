// repro_uninit_mut_binding.nr.
// Pre-fix `let mut x: i64;` created a named binding backed by the
// alloca zero slot. If a path read `x` before assignment, it silently
// observed 0 instead of a definite-assignment diagnostic.
//
// EXPECT: build fails (msg contains "without initializer").

fn main() -> i64 {
    let mut x: i64;
    if false {
        x = 5;
    };
    println!("{}", x);
    return 0;
}
