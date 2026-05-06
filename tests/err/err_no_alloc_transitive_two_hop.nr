// EXPECT: RT-001 call to `format_wrapper()` reaches same-file allocation
// RT-G1 Phase 2b: #[no_alloc] catches caller -> helper -> allocator
// in one additional same-file closure layer.

fn format_path(x: i64) -> str {
    return str_concat("axis=", int_to_str(x));
}

fn format_wrapper(x: i64) -> str {
    return format_path(x);
}

#[no_alloc]
fn motor_step(x: i64) -> i64 {
    let label: str = format_wrapper(x);
    return str_len(label);
}

fn main() -> i64 {
    return motor_step(7);
}
