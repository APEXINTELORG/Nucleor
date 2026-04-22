// Test for-in loop over array
// Expected output: 10\n20\n30\n60

fn main() -> i32 {
    let arr: [i32; 3] = [10, 20, 30];
    let mut sum: i32 = 0;

    for x in arr {
        print_int(x);
        sum = sum + x;
    }

    print_int(sum);
    0
}
