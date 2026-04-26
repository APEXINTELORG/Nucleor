// Probe NUC-FEEDBACK-010 v2: full long name
struct ShapeDtypeContract {
    compile_time_shape_assertion_count: i64,
    other: i64,
}

fn main() -> i64 {
    let c: ShapeDtypeContract = ShapeDtypeContract { compile_time_shape_assertion_count: 7, other: 3 };
    let n: i64 = c.compile_time_shape_assertion_count;
    println!("{}", n);
    return 0;
}
