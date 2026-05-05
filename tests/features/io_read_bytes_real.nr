// Internal probe — reads 5 bytes from stdin and prints them.
// Used by tools/test_io_read_bytes.ps1 for integration verify.
import "stdlib/rods/io.nr"
fn main() -> i64 {
    let s: str = io_read_bytes(5);
    io_println(s);
    if str_len(s) == 5 { return 0; };
    return 1;
}
