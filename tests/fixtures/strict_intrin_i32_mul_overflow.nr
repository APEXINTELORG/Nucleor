// strict_intrin_i32_mul_overflow.nr.
// Track E: signed i32 mul must lower through llvm.smul.with.overflow.i32
// when NUCLEOR_INT_STRICT_INTRIN=1.

fn main() -> i32 {
    let a: i32 = 50000;
    let b: i32 = 50000;
    let _c: i32 = a * b;
    return 0;
}

