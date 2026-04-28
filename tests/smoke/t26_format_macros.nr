// T2.6 (v0.2.346) smoke: println! / print! / format! macros.
// Source-level expansion in the resolver — the parser never sees
// the macro syntax. Format spec syntax mirrors Rust:
//   {}    — int_to_str(arg)   (default)
//   {:i}  — int_to_str(arg)   (alias)
//   {:s}  — arg as-is         (str passthrough)
//   {:f}  — f64_to_str(arg)
//   {:b}  — binary radix (v0.4.29; was bool_to_str pre-v0.4.29)
//   {:x}  — hex radix (v0.4.29)
//   {:o}  — octal radix (v0.4.29)
//   {{ }} — literal `{` / `}`

#[test]
fn test_format_basic_int() {
    let n: i64 = 42;
    let out: str = format!("got {} items", n);
    // "got 42 items" = 12 chars
    assert_eq(str_len(out), 12);
    assert_eq(str_char_at(out, 0), 103);   // 'g'
    assert_eq(str_char_at(out, 4), 52);    // '4'
    assert_eq(str_char_at(out, 5), 50);    // '2'
}

#[test]
fn test_format_two_placeholders() {
    let a: i64 = 10;
    let b: i64 = 20;
    let out: str = format!("{} + {} = {}", a, b, a + b);
    // "10 + 20 = 30" = 12 chars
    assert_eq(str_len(out), 12);
    assert_eq(str_char_at(out, 0), 49);    // '1'
    assert_eq(str_char_at(out, 1), 48);    // '0'
    assert_eq(str_char_at(out, 5), 50);    // '2'
    assert_eq(str_char_at(out, 10), 51);   // '3'
}

#[test]
fn test_format_str_passthrough() {
    let name: str = "world";
    let out: str = format!("hello, {:s}!", name);
    // "hello, world!" = 13 chars
    assert_eq(str_len(out), 13);
    assert_eq(str_char_at(out, 7), 119);   // 'w'
}

#[test]
fn test_format_literal_only() {
    let out: str = format!("no placeholders here");
    // "no placeholders here" = 20 chars
    assert_eq(str_len(out), 20);
}

#[test]
fn test_format_escaped_braces() {
    let out: str = format!("{{ }} = literal braces");
    // "{ } = literal braces" = 20 chars
    assert_eq(str_len(out), 20);
    assert_eq(str_char_at(out, 0), 123);   // '{'
    assert_eq(str_char_at(out, 2), 125);   // '}'
}

#[test]
fn test_format_binary_radix() {
    // v0.4.29: `:b` is binary radix (Rust convention).
    // Pre-v0.4.29 it routed to bool_to_str; that was a non-Rust dialect
    // and is now corrected.
    let n: i64 = 10;
    let out: str = format!("bits = {:b}", n);
    // "bits = 1010" = 11 chars
    assert_eq(str_len(out), 11);
    assert_eq(str_char_at(out, 7), 49);    // '1'
    assert_eq(str_char_at(out, 10), 48);   // '0'
}
