// strict_intrin_i8_add_overflow.nr.
// Track E: signed i8 add must lower through llvm.sadd.with.overflow.i8
// when NUCLEOR_INT_STRICT_INTRIN=1.

fn main() -> i32 {
    let a: i8 = 120;
    let b: i8 = 10;
    let _c: i8 = a + b;
    return 0;
}

