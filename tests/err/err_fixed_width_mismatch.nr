// EXPECT: error[TYP-008] type mismatch for binding 'b'
// R09-D1 / RFC-0043: fixed<I,F> widths are semantic type metadata,
// not just erased i64 storage. Assigning fixed<8,8> to fixed<16,16>
// must fail instead of silently accepting the raw i64 cell.

fn main() -> i64 {
    let a: fixed<8, 8> = 1;
    let b: fixed<16, 16> = a;
    return b;
}
