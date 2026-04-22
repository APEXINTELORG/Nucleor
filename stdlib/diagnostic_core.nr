// Nucleor stdlib: diagnostic_core
// Compiler diagnostic infrastructure for bootstrap.

struct Diagnostic {
    code: i32,
    severity: i32,
    start: i32,
    end: i32,
}

fn make_error(code: i32, start: i32, end: i32) -> Diagnostic {
    Diagnostic { code: code, severity: 0, start: start, end: end }
}

fn make_warning(code: i32, start: i32, end: i32) -> Diagnostic {
    Diagnostic { code: code, severity: 1, start: start, end: end }
}

fn main() -> i32 {
    let e: Diagnostic = make_error(31, 100, 115);
    // Access fields directly instead of passing to functions (struct moves)
    print_int(e.code);
    print_int(e.start);
    print_bool(e.severity == 0);

    let w: Diagnostic = make_warning(30, 200, 210);
    print_int(w.code);
    print_bool(w.severity == 1);
    0
}
