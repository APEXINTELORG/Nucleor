// Test Vec fold combinator
// Expected output: 100

fn main() -> i32 {
    let v: Vec<i32> = Vec::new();
    v.push(10);
    v.push(20);
    v.push(30);
    v.push(40);

    // fold: sum all elements
    let total: i32 = v.fold(0, |acc: i32, x: i32| acc + x);
    print_int(total);

    0
}
