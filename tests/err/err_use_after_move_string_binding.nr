// EXPECT: OWN-001 use of moved variable
// Binding transfer of a heap String must move the source handle.

fn main() -> i32 {
    let s: String = String::new();
    let t: String = s;
    let n: i64 = s.len();
    print_int(n);
    print_int(t.len());
    0
}
