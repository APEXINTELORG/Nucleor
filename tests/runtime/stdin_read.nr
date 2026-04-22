// stdin_read — RFC-0015 phase 4 completion: stdin read primitives.
//
// Tests the EOF return contract since the gate runs without a TTY.
// `read_byte()` returns -1 at EOF; `read_line()` returns "" at EOF;
// `read_i64()` returns 0 on parse failure (which includes EOF).

fn main() -> i64 {
    let mut fail: i64 = 0;

    // read_byte: -1 on EOF (no stdin attached on the gate).
    let b: i64 = read_byte();
    if b != (0 - 1) { fail = fail + 1; print("FAIL read_byte EOF"); };

    // read_line: empty string on EOF.
    let line: str = read_line();
    if str_len(line) != 0 { fail = fail + 1; print("FAIL read_line EOF"); };

    // read_i64: 0 on parse failure.
    let n: i64 = read_i64();
    if n != 0 { fail = fail + 1; print("FAIL read_i64 EOF"); };

    if fail == 0 { print("OK stdin_read"); return 0; };
    return 1;
}
