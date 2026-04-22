// Error test: transitive effect violation
// middle() calls read_sensor() which requires [io.read]
// main restricts [io] but calls middle()
fn read_sensor() -> i32 requires [io.read] {
    42
}

fn middle() -> i32 requires [io.read] {
    read_sensor()
}

fn main() -> i32 {
    restricts [io] {
        // middle requires io.read — this must fail
        middle()
    }
}
