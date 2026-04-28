// repro_v58_str_arith_guard.nr
//
// v0.4.58 NUC-FEEDBACK silent-segfault guard for str arithmetic
// (`str - str`, `str * str`, `str / str`, `str % str`). Pre-fix
// each of these lowered to integer arithmetic on the string pointers,
// producing garbage that SIGSEGVed when used. Only `+` had the
// v0.4.51 guard.
//
// v0.4.58 extends TYP-011 to ops 21/22/23/24 with a clear message.

fn main() -> i64 {
    let a: str = "hello";
    let b: str = "world";
    let bad: str = a - b;   // TYP-011 expected
    println!("{}", bad);
    return 0;
}
