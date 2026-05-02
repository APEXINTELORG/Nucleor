// RFC-0008 first-pass positive: safe ISR body inherits no_alloc/no_panic
// semantics without blocking a normal build.

#[isr(prio = 1)]
fn uart_rx_handler() {
    let x: i64 = 1;
    let y: i64 = x + 1;
}

fn main() -> i32 {
    print("OK rfc0008_isr_no_alloc_no_panic\n");
    return 0;
}
