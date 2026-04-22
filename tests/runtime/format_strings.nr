// format_strings — RFC-0028 phase 1: format builtins.
//
// One {} placeholder per call (multi-placeholder via format2_*).
// Variadic format strings + Display/Debug traits ship in v0.4.

fn main() -> i64 {
    let mut fail: i64 = 0;

    if str_eq(format_i64("answer = {}", 42), "answer = 42") == 0 {
        fail = fail + 1; print("FAIL format_i64");
    };
    if str_eq(format_str("hello, {}!", "world"), "hello, world!") == 0 {
        fail = fail + 1; print("FAIL format_str");
    };
    if str_eq(format_hex("addr = {}", 4096), "addr = 0x1000") == 0 {
        fail = fail + 1; print("FAIL format_hex");
    };
    if str_eq(format2_ii("{} + {} = ?", 3, 4), "3 + 4 = ?") == 0 {
        fail = fail + 1; print("FAIL format2_ii");
    };
    if str_eq(format2_si("user {} is {} years old", "alice", 30), "user alice is 30 years old") == 0 {
        fail = fail + 1; print("FAIL format2_si");
    };

    // No placeholder — template returned verbatim.
    if str_eq(format_i64("no placeholder", 99), "no placeholder") == 0 {
        fail = fail + 1; print("FAIL no-placeholder verbatim");
    };

    // Negative number renders correctly.
    if str_eq(format_i64("{}", 0 - 7), "-7") == 0 {
        fail = fail + 1; print("FAIL negative i64");
    };

    if fail == 0 { print("OK format_strings"); return 0; };
    return 1;
}
