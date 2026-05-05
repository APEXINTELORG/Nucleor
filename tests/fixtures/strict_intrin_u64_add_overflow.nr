// strict_intrin_u64_add_overflow.nr.
// A2: u64 add must lower through llvm.uadd.with.overflow.i64
// when NUCLEOR_INT_STRICT_INTRIN=1.

fn add_u64(a: u64, b: u64) -> u64 {
    return a + b;
}

fn main() -> i32 {
    let _c: u64 = add_u64(18446744073709551615, 1);
    return 0;
}
