// strict_intrin_i16_sub_overflow.nr.
// Track E: signed i16 sub must lower through llvm.ssub.with.overflow.i16
// when NUCLEOR_INT_STRICT_INTRIN=1.

fn main() -> i32 {
    let a: i16 = 0 - 32760;
    let b: i16 = 20;
    let _c: i16 = a - b;
    return 0;
}

