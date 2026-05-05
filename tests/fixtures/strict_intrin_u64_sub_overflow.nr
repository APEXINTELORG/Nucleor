// strict_intrin_u64_sub_overflow.nr.
// A2: u64 sub must lower through llvm.usub.with.overflow.i64
// when NUCLEOR_INT_STRICT_INTRIN=1.

fn sub_u64(a: u64, b: u64) -> u64 {
    return a - b;
}

fn main() -> i32 {
    let _c: u64 = sub_u64(0, 1);
    return 0;
}
