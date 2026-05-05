// strict_intrin_u64_mul_overflow.nr.
// A2: u64 mul must lower through llvm.umul.with.overflow.i64
// when NUCLEOR_INT_STRICT_INTRIN=1.

fn mul_u64(a: u64, b: u64) -> u64 {
    return a * b;
}

fn main() -> i32 {
    let _c: u64 = mul_u64(4294967296, 4294967296);
    return 0;
}
