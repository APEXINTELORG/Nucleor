// Test Vec::iter() - non-owning borrowing iterator
// Expected output: true\nfalse\n6\n3

fn main() -> i32 {
    let v: Vec<i32> = Vec::new();
    v.push(1);
    v.push(2);
    v.push(3);

    // Use .iter() to borrow - v should remain valid after each call
    let has_big: bool = v.iter().any(|x: i32| x > 2);
    print_bool(has_big);  // true

    let has_neg: bool = v.iter().any(|x: i32| x < 0);
    print_bool(has_neg);  // false

    let total: i32 = v.iter().sum();
    print_int(total);  // 6

    // v is still valid
    print_int(v.len());  // 3

    0
}
