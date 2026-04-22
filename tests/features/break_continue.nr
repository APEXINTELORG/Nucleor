fn main() -> i32 {
    // Test break: sum 1..10, but break when i == 5
    let mut sum: i32 = 0;
    let mut i: i32 = 1;
    while i <= 10 {
        if i == 5 {
            break;
        };
        sum = sum + i;
        i = i + 1;
    };
    print_int(sum);

    // Test continue: sum 1..5, skipping 3
    let mut sum2: i32 = 0;
    let mut j: i32 = 0;
    while j < 5 {
        j = j + 1;
        if j == 3 {
            continue;
        };
        sum2 = sum2 + j;
    };
    print_int(sum2);

    0
}
