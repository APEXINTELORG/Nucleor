// RFC-0008 first-pass positive: #[isr] parses, survives DCE, and emits
// a stable ISR IR marker while preserving normal host build/run behavior.

#[isr]
fn systick_handler() {
}

fn main() -> i32 {
    print("OK rfc0008_isr_minimal\n");
    return 0;
}
