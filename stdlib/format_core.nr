// Nucleor stdlib: format_core
// Formatting primitives for bootstrap compiler diagnostics.

fn print_line(s: str) -> i32 {
    print(s);
    0
}

fn print_int_line(label: str, value: i32) -> i32 {
    print(label);
    print_int(value);
    0
}

fn print_bool_line(label: str, value: bool) -> i32 {
    print(label);
    print_bool(value);
    0
}

fn print_separator() -> i32 {
    print("---");
    0
}

fn main() -> i32 {
    print_line("=== Format Core Test ===");
    print_int_line("count: ", 42);
    print_bool_line("ok: ", true);
    print_separator();
    0
}
