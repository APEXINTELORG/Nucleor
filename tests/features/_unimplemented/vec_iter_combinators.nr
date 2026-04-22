// Test Vec::iter() with various combinators
// Expected output: 6\n3\n3\n1\n2\n2\n2\n4\n6\n3

fn main() -> i32 {
    let v: Vec<i32> = Vec::new();
    v.push(1);
    v.push(2);
    v.push(3);

    // iter().sum()
    let total: i32 = v.iter().sum();
    print_int(total);  // 6

    // iter().count()
    let cnt: i32 = v.iter().count();
    print_int(cnt);  // 3

    print_int(v.iter().count());  // 3

    // iter().take(2)
    let first2: Vec<i32> = v.iter().take(2);
    for x in first2 {
        print_int(x);  // 1, 2
    }

    // iter().filter()
    let evens: Vec<i32> = v.iter().filter(|x: i32| x % 2 == 0);
    for x in evens {
        print_int(x);  // 2
    }

    // iter().map()
    let doubled: Vec<i32> = v.iter().map(|x: i32| x * 2);
    for x in doubled {
        print_int(x);  // 2, 4, 6
    }

    // v still valid after all those borrows
    print_int(v.len());  // 3

    0
}
