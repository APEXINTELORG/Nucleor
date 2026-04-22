// Test iterator combinators
// Expected output shown in comments

fn main() -> i32 {
    // take
    let v1: Vec<i32> = Vec::new();
    v1.push(10);
    v1.push(20);
    v1.push(30);
    let first2: Vec<i32> = v1.take(2);
    print_int(first2.len());  // 2
    print_int(first2.sum());  // 30

    // skip
    let v2: Vec<i32> = Vec::new();
    v2.push(10);
    v2.push(20);
    v2.push(30);
    let rest: Vec<i32> = v2.skip(1);
    print_int(rest.len());  // 2
    print_int(rest.sum());  // 50

    // chain
    let a: Vec<i32> = Vec::new();
    a.push(1);
    a.push(2);
    let b: Vec<i32> = Vec::new();
    b.push(3);
    b.push(4);
    let ab: Vec<i32> = a.chain(b);
    print_int(ab.len());  // 4
    print_int(ab.sum());  // 10

    // any / all
    let v3: Vec<i32> = Vec::new();
    v3.push(1);
    v3.push(2);
    v3.push(3);
    let has2: bool = v3.any(|x: i32| x == 2);
    print_bool(has2);  // true

    let v4: Vec<i32> = Vec::new();
    v4.push(1);
    v4.push(2);
    v4.push(3);
    let all_pos: bool = v4.all(|x: i32| x > 0);
    print_bool(all_pos);  // true

    // sum / count
    let v5: Vec<i32> = Vec::new();
    v5.push(10);
    v5.push(20);
    v5.push(30);
    print_int(v5.sum());   // 60

    let v6: Vec<i32> = Vec::new();
    v6.push(10);
    v6.push(20);
    v6.push(30);
    print_int(v6.count()); // 3

    0
}
