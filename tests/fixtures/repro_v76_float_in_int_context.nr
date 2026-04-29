// repro_v76_float_in_int_context.nr — v0.4.76 NUM-018.
// Pre-fix `let x: i64 = 3.14;` types_compatible returned 1 (line
// 10063 allows i*/u* expected to accept f64 actual — legacy from
// when narrow-float values flowed through i64 cells). The init
// was bit-cast: x got 4614253070214989087 (the IEEE 754 bit
// pattern of 3.14 reinterpreted as i64). Total silent miscompute.
// Adopters writing canonical Rust got E0308 mismatched types.
//
// v0.4.76 promotes literal-float-in-int-binding to NUM-018
// (already reserved in RFC-0015 / v0.2.319 expansion).
//
// EXPECT: build fails with NUM-018 (msg contains "float literal").

fn main() -> i64 {
    let x: i64 = 3.14;
    println!("{}", x);
    return 0;
}
