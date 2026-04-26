// Probe NUC-FEEDBACK-010: `static` in field name breaks resolution
struct Contract {
    static_shape_count: i64,
    other: i64,
}

fn main() -> i64 {
    let c: Contract = Contract { static_shape_count: 7, other: 3 };
    let n: i64 = c.static_shape_count;
    println!("{}", n);
    return 0;
}
