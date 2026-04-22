// strings.nr — core string ops
fn main() -> i64 {
    let mut fail: i64 = 0;
    if str_eq("hi", "hi") != 1 { print("FAIL strings: eq"); fail = fail + 1; };
    if str_eq("hi", "bye") == 1 { print("FAIL strings: eq mismatch"); fail = fail + 1; };
    if str_len("nucleor") != 7 { print("FAIL strings: len"); fail = fail + 1; };
    let s: str = str_concat("Hello, ", "world!");
    if str_eq(s, "Hello, world!") != 1 { print("FAIL strings: concat"); fail = fail + 1; };
    let sub: str = str_substring("nucleor", 0, 3);
    if str_eq(sub, "nuc") != 1 { print("FAIL strings: substring"); fail = fail + 1; };
    if str_char_at("abc", 1) != 98 { print("FAIL strings: char_at"); fail = fail + 1; };
    if fail == 0 { print("OK strings"); return 0; };
    return 1;
}
