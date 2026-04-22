// Error test: effect inference — middle() calls read_sensor() which requires
// [io.read], but middle() does NOT declare it. The compiler infers it
// transitively and restricts [io] catches the violation.
fn read_sensor() -> i32 requires [io.read] { 42 }

fn middle() -> i32 {
    // Calls effectful function without declaring requires
    read_sensor()
}

fn main() -> i32 {
    restricts [io] {
        // middle() has inferred io.read — must fail
        middle()
    }
}
