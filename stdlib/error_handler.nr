// Nucleor stdlib: error_handler
// Structured error reporting for bootstrap compiler.
// Collects diagnostics with source positions and renders them.

const SEV_ERROR: i32 = 0;
const SEV_WARNING: i32 = 1;
const SEV_NOTE: i32 = 2;

// Error code ranges (matches NRxxx scheme)
const EC_SOURCE: i32 = 1;
const EC_MODULE: i32 = 5;
const EC_LEX: i32 = 10;
const EC_PARSE: i32 = 20;
const EC_TYPE: i32 = 30;
const EC_BORROW: i32 = 31;
const EC_EFFECT: i32 = 32;
const EC_TAINT: i32 = 33;
const EC_SEND: i32 = 34;
const EC_LOWER: i32 = 40;
const EC_CODEGEN: i32 = 50;
const EC_MANIFEST: i32 = 70;
const EC_PIPELINE: i32 = 90;

fn error_code_prefix(code: i32) -> str {
    if code < 10 { "NR00" }
    else if code < 100 { "NR0" }
    else { "NR" }
}

fn severity_label(sev: i32) -> str {
    if sev == SEV_ERROR { "error" }
    else if sev == SEV_WARNING { "warning" }
    else { "note" }
}

fn is_fatal(sev: i32) -> bool {
    sev == SEV_ERROR
}

// Error accumulator state
struct ErrorState {
    error_count: i32,
    warning_count: i32,
    max_errors: i32,
}

fn error_state_new(max: i32) -> ErrorState {
    ErrorState { error_count: 0, warning_count: 0, max_errors: max }
}

fn should_stop(errors: i32, max: i32) -> bool {
    max > 0 && errors >= max
}

fn has_errors(count: i32) -> bool {
    count > 0
}

fn main() -> i32 {
    print(severity_label(SEV_ERROR));
    print(severity_label(SEV_WARNING));
    print(severity_label(SEV_NOTE));
    print_bool(is_fatal(SEV_ERROR));
    print_bool(is_fatal(SEV_WARNING));

    let st: ErrorState = error_state_new(100);
    print_int(st.error_count);
    print_bool(should_stop(50, 100));
    print_bool(should_stop(100, 100));
    print_bool(has_errors(0));
    print_bool(has_errors(3));
    0
}
