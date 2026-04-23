// EXPECT: TYP-006 argument type mismatch in call
// Taint propagates through binary op into clean sink.
// Error test: taint propagates through arithmetic — result is still tainted
fn get_input() -> tainted<i32> {
    10
}

fn clean_sink(x: i32) -> i32 {
    x + 1
}

fn main() -> i32 {
    let dirty: tainted<i32> = get_input();
    let clean: i32 = 5;
    // Taint propagates: tainted + clean = tainted
    let mixed: tainted<i32> = dirty + clean;
    // This must fail — mixed is still tainted
    clean_sink(mixed)
}
