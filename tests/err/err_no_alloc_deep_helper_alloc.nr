// EXPECT: RT-001 call to `format_top()` reaches same-file allocation
// RT-G1 v0842: #[no_alloc] catches a deeper same-file helper chain.

fn format_leaf(x: i64) -> str {
    return str_concat("axis=", int_to_str(x));
}

fn format_mid(x: i64) -> str {
    return format_leaf(x);
}

fn format_top(x: i64) -> str {
    return format_mid(x);
}

#[no_alloc]
fn motor_step(x: i64) -> i64 {
    let label: str = format_top(x);
    return str_len(label);
}

fn main() -> i64 {
    return motor_step(7);
}
