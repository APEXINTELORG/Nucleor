// Test: Vec push with const values
const MY_TEN: i32 = 10;
const MY_TWENTY: i32 = 20;

fn push_const(v: Vec<i32>, val: i32) -> i32 {
    v.push(val);
    0
}

fn main() -> i32 {
    let mut v: Vec<i32> = Vec::new();
    // Direct push with literal
    v.push(10);
    v.push(20);
    print_int(v.get(0));
    print_int(v.get(1));

    // Push via const
    let mut v2: Vec<i32> = Vec::new();
    v2.push(MY_TEN);
    v2.push(MY_TWENTY);
    print_int(v2.get(0));
    print_int(v2.get(1));

    // Push via variable set to const
    let mut v3: Vec<i32> = Vec::new();
    let val: i32 = MY_TEN;
    v3.push(val);
    print_int(v3.get(0));

    // Push result of if-else expression
    let mut v4: Vec<i32> = Vec::new();
    let cond: bool = true;
    let tk: i32 = if cond { MY_TEN } else { MY_TWENTY };
    v4.push(tk);
    print_int(v4.get(0));

    // Push from inside if-else (like the lexer does)
    let mut v5: Vec<i32> = Vec::new();
    let c: i32 = 40;
    if c == 40 {
        v5.push(MY_TEN);
    } else {
        v5.push(MY_TWENTY);
    };
    print_int(v5.get(0));

    0
}
