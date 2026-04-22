// Error test: restricts [sync] blocks channel syntax
fn main() -> i32 {
    restricts [sync] {
        let _ch: i64 = channel(2);
        0
    }
}
