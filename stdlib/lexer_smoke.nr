// Smoke test for lexer primitives

fn main() -> i32 {
    // Test str_char_at
    let s: str = "hello";
    let c0: i32 = str_char_at(s, 0);
    let c1: i32 = str_char_at(s, 1);
    print_int(c0);  // 104 = 'h'
    print_int(c1);  // 101 = 'e'

    // Test str_substring
    let sub: str = str_substring(s, 1, 3);
    print(sub);  // "el"

    // Test Vec<i32> push/get
    let mut v: Vec<i32> = Vec::new();
    v.push(10);
    v.push(20);
    v.push(30);
    print_int(v.len());  // 3
    print_int(v.get(0));  // 10
    print_int(v.get(1));  // 20
    print_int(v.get(2));  // 30

    // Test continue in while loop
    let mut i: i32 = 0;
    let mut count: i32 = 0;
    while i < 5 {
        i = i + 1;
        if i == 3 {
            continue;
        };
        count = count + 1;
    };
    print_int(count);  // 4 (skipped i==3)

    0
}
