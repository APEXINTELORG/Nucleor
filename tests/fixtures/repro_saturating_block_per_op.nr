// repro_saturating_block_per_op.nr.
// Pre-fix `saturating { ... }` clamped only the final block result to
// i32 range after inner arithmetic had already wrapped. It did not
// implement per-operation i64 saturating add/sub/mul.

fn main() -> i64 {
    let max: i64 = 9223372036854775807;
    let one: i64 = 1;
    let two: i64 = 2;
    let five: i64 = 5;
    let neg_ten: i64 = 0 - 10;

    let add_then_sub: i64 = saturating { (max + one) - five };
    if add_then_sub != max - five {
        print("FAIL saturating add then sub\n");
        return 1;
    };

    let sub_hi: i64 = saturating { max - neg_ten };
    if sub_hi != max {
        print("FAIL saturating sub high\n");
        return 2;
    };

    let mul_hi: i64 = saturating { max * two };
    if mul_hi != max {
        print("FAIL saturating mul high\n");
        return 3;
    };

    let normal: i64 = saturating { 40 + two };
    if normal != 42 {
        print("FAIL saturating normal add\n");
        return 4;
    };

    print("OK saturating block per op\n");
    return 0;
}
