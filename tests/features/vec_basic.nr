// Phase 5e: Basic Vec<i32> operations

fn main() -> i32 {
    let v: Vec<i32> = Vec::new();
    v.push(10);
    v.push(20);
    v.push(30);
    let length: i32 = v.len();
    print_int(length);
    let first: i32 = v.get(0);
    print_int(first);
    let second: i32 = v.get(1);
    print_int(second);
    let third: i32 = v.get(2);
    print_int(third);
    0
}
