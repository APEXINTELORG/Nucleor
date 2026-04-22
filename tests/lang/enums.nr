// enums.nr — enums and match
// V2's type checker treats each enum as its own type, so function parameters
// must declare the enum type explicitly (not i64).

enum Option {
    None,
    Some(i64)
}

enum Color {
    Red,
    Green,
    Blue
}

fn unwrap_or(o: Option, default: i64) -> i64 {
    match o {
        Option::None => { return default; },
        Option::Some(v) => { return v; },
    };
}

fn color_code(c: Color) -> i64 {
    match c {
        Color::Red => { return 1; },
        Color::Green => { return 2; },
        Color::Blue => { return 3; },
    };
}

fn main() -> i32 {
    if unwrap_or(Option::None, 99) != 99 { print("FAIL enums: None default"); return 1; };
    if unwrap_or(Option::Some(42), 0) != 42 { print("FAIL enums: Some value"); return 1; };
    if color_code(Color::Red) != 1 { print("FAIL enums: red"); return 1; };
    if color_code(Color::Green) != 2 { print("FAIL enums: green"); return 1; };
    if color_code(Color::Blue) != 3 { print("FAIL enums: blue"); return 1; };
    print("OK enums");
    return 0;
}
