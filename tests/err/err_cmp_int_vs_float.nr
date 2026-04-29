// EXPECT: error[NUM-022] integer (`i32`) and float (`f64`) operands in comparison binop
// v0.4.137: int-vs-float in cmp ops silently bit-pattern-compared
// as raw i64 — `5 == 5.0` returned FALSE because i64=5 (0x5) ≠
// f64 5.0 bit pattern (0x4014000000000000); `5 < 5.0` returned
// TRUE because i64=5 reinterpreted as f64 is a tiny denormal
// (~2.5e-323). Sister to v0.4.132 (binop void). Catches cmp ops
// 30-37 (==, !=, <, <=, >, >=) when one side is int and the
// other float. Mirrored to nucleor_tools_suite.nr (with inlined
// predicate since tools_suite has no type_is_int/type_is_float).

fn main() -> i32 {
    let r: bool = 5 == 5.0;
    print_int(r as i64);
    0
}
