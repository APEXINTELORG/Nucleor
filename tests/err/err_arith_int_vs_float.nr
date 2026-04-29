// EXPECT: error[NUM-022] integer (`i32`) and float (`f64`) operands in arithmetic binop
// v0.4.141: extends v0.4.137 NUM-022 to arithmetic ops 20-24
// (+, -, *, /, %). Pre-fix `5 + 5.0` produced 4617315517961601024
// — the i64 bit pattern of 5 added to the f64 bit pattern of 5.0
// (interpreted as i64). The result is large/obviously wrong, but
// adopters writing canonical Rust math get a silent-pass build
// with garbage values. Sister to v0.4.137 (cmp version).
// Mirrored to nucleor_tools_suite.nr.

fn main() -> i32 {
    let r = 5 + 5.0;
    print_int(r as i64);
    0
}
