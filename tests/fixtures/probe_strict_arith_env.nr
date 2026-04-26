// Probe: under NUCLEOR_INT_STRICT_ARITH=1 the binop a+b should
// emit __nucleor_panic_add_i64 instead of native LLVM add.
fn main() -> i64 {
    let a: i64 = 9223372036854775000;
    let b: i64 = 9223372036854775000;
    let r: i64 = a + b;
    println!("{}", r);
    return 0;
}
