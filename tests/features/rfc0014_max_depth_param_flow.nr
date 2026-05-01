// RFC-0014 extension positive: the bounded counter does not need to be
// the first parameter or be named `depth`.

#[max_depth = 5]
fn accumulate_until(acc: i64, remaining: i64) -> i64 {
    if remaining <= 0 {
        return acc;
    };
    return accumulate_until(acc + 1, remaining - 1);
}

fn main() -> i64 {
    let got: i64 = accumulate_until(10, 3);
    if got != 13 { return 1; };
    print("OK rfc0014_max_depth_param_flow");
    return 0;
}
