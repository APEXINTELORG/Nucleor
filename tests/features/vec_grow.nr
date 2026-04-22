// Phase 5e: Vec growth beyond initial capacity

fn main() -> i32 {
    let v: Vec<i32> = Vec::new();
    let mut i: i32 = 0;
    while i < 20 {
        v.push(i * 10);
        i = i + 1;
    }
    print_int(v.len());
    print_int(v.get(0));
    print_int(v.get(9));
    print_int(v.get(19));
    0
}
