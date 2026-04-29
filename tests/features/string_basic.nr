// Phase 5e: Basic String operations

fn main() -> i32 {
    let s: String = String::new();
    s.push(72);
    s.push(101);
    s.push(108);
    s.push(108);
    s.push(111);
    let length: i32 = s.len();
    print_int(length);
    0
}
