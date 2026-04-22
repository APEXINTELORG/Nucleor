// Error test: restricts block denies effects
fn read_data() -> i32 requires [io.read] {
    42
}

fn main() -> i32 {
    // restricts [io] denies ALL io effects
    restricts [io] {
        let x: i32 = read_data();
        x
    }
}
