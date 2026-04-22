// Error test: restricts [io.read] blocks io.read specifically
fn read_data() -> i32 requires [io.read] { 42 }
fn write_data(x: i32) requires [io.write] { putchar(x); }

fn main() -> i32 {
    // Deny only io.read — io.write should still work
    restricts [io.read] {
        write_data(65);   // This is fine — io.write not denied
        read_data()       // This must fail — io.read IS denied
    }
}
