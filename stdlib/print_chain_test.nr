// Test: 16-branch if-else chain with print calls

fn print_big(v: i32) -> i32 {
    if v == 1 { print("a"); }
    else if v == 2 { print("b"); }
    else if v == 3 { print("c"); }
    else if v == 4 { print("d"); }
    else if v == 5 { print("e"); }
    else if v == 6 { print("f"); }
    else if v == 7 { print("g"); }
    else if v == 8 { print("h"); }
    else if v == 9 { print("i"); }
    else if v == 10 { print("j"); }
    else if v == 11 { print("k"); }
    else if v == 12 { print("l"); }
    else if v == 13 { print("m"); }
    else if v == 14 { print("n"); }
    else if v == 15 { print("o"); }
    else if v == 16 { print("p"); }
    else { print("?"); };
    0
}

fn main() -> i32 {
    let mut i: i32 = 1;
    while i <= 17 {
        print_big(i);
        i = i + 1;
    };
    print("done");
    0
}
