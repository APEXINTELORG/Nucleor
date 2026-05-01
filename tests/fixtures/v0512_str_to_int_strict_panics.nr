// Runtime-panic fixture for v0.5.12 str_to_int_strict.
// Asserts strict variant panics on a representative invalid input.
//
// Runtime expectations (verified by `v0512_str_to_int_strict_panic`
// step in tools/verify.sh):
//   - rc != 0
//   - stderr contains "PANIC: str_to_int_strict:"

fn main() -> i32 {
    let v: i64 = str_to_int_strict("not a number");
    print_int(v as i32);
    0
}
