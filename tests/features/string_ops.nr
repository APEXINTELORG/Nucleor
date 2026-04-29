fn main() -> i32 {
    // Test str_concat
    let greeting: str = str_concat("hello ", "world");
    print(greeting);

    // Test str_len
    let n: i32 = str_len("hello world");
    print_int(n);

    // Test str_eq
    let same: bool = str_eq("hello world", "hello world");
    print_bool(same);

    // Test fmod
    let r: f64 = fmod(10.5, 3.0);
    print_f64(r);

    // Test fabs
    let a: f64 = fabs(-2.5);
    print_f64(a);

    0
}
