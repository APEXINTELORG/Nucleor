// Test Vec map and filter combinators
// Expected output: 4\n2\n4\n6\n8\n2\n4\n6\n8

fn main() -> i32 {
    let v: Vec<i32> = Vec::new();
    v.push(1);
    v.push(2);
    v.push(3);
    v.push(4);

    // map: double each element
    let doubled: Vec<i32> = v.map(|x: i32| x * 2);
    let dlen: i32 = doubled.len();
    print_int(dlen);

    for x in doubled {
        print_int(x);
    }

    // filter: keep only even elements from original
    let evens: Vec<i32> = v.filter(|x: i32| x % 2 == 0);
    for x in evens {
        print_int(x);
    }

    // Combined: filter evens from doubled
    let big_evens: Vec<i32> = doubled.filter(|x: i32| x > 4);
    for x in big_evens {
        print_int(x);
    }

    0
}
