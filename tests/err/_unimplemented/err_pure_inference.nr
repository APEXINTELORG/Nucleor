// Error test: pure function catches inferred effects
// effectful() declares [io.read], wrapper() calls it without declaring
// pure fn should catch the inferred effect on wrapper()
fn effectful() -> i32 requires [io.read] { 42 }
fn wrapper() -> i32 { effectful() }

pure fn should_fail() -> i32 {
    wrapper()
}

fn main() -> i32 { should_fail() }
