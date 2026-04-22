// Test for-in loop over Vec
// Expected output: 5\n10\n15\n20\n50

fn main() -> i32 {
    let v: Vec<i32> = Vec::new();
    v.push(5);
    v.push(10);
    v.push(15);
    v.push(20);

    let mut total: i32 = 0;
    for x in v {
        print_int(x);
        total = total + x;
    }

    print_int(total);
    0
}
