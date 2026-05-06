// EXPECT: RT-001 call to `format_path()` reaches same-file allocation
// RT-G1 Phase 1.5: #[no_alloc] now catches a one-hop same-file call
// into a helper whose own body allocates.

fn format_path(x: i64) -> str {
    return str_concat("axis=", int_to_str(x));
}

#[no_alloc]
fn motor_step(x: i64) -> i64 {
    let label: str = format_path(x);
    return str_len(label);
}

fn main() -> i64 {
    return motor_step(7);
}
