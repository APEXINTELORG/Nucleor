// v0.4.91: `{:?}` on a user struct produces structural Debug text.

struct Sample {
    name: str,
    count: i64,
    ok: bool,
}

fn main() -> i64 {
    let sample: Sample = Sample { name: "alpha", count: 7, ok: true };
    let s: str = format!("{:?}", sample);
    if str_eq(s, "Sample { name: \"alpha\", count: 7, ok: true }") != 1 {
        print(s);
        return 1;
    };
    println!("{:?}", sample);
    return 0;
}
