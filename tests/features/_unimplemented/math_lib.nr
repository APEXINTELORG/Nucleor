// A library module with math utilities

pub fn square(x: i32) -> i32 {
    x * x
}

fn cube(x: i32) -> i32 {
    x * x * x
}

fn max(a: i32, b: i32) -> i32 {
    if a > b { a } else { b }
}

fn main() -> i32 {
    let s: i32 = square(5);
    let c: i32 = cube(3);
    let m: i32 = max(s, c);
    print_int(s);
    print_int(c);
    print_int(m);
    0
}
