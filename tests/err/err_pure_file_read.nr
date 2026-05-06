// EXPECT: EFF-001 file_read_string
// Negative fixture for EFF-001 — pure fn calling file IO.
//
// `file_read_string` does file IO and allocates the buffer. Pre-
// v0.8.323 a pure fn calling file_read_string was silently accepted.
// v0.8.323 (RFC-0063 Phase 1.5) detects the call and fires EFF-001
// naming file_read_string.
//
// Expected: error[EFF-001] mentioning file_read_string.

pure fn impure_via_file_read(path: str) -> i64 {
    let s: str = file_read_string(path);
    return str_len(s);
}

fn main() -> i64 {
    return impure_via_file_read("/tmp/nonexistent");
}
