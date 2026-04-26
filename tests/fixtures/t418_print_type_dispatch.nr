// t418_print_type_dispatch.nr — v0.3.143 NUC-FEEDBACK-008 fixture.
//
// Pre-v0.3.143, every `print(arg)` call lowered to
// `__nucleor_print_str(arg)` regardless of arg's type. When arg was
// an i64 (e.g. token count, counter, literal), the string helper
// dereferenced the integer as a `const char *` pointer and crashed
// with SIGSEGV — visible to the adopter as silent program
// termination mid-output (exit 1 or 139, remaining prints just
// gone). Same hazard class as the contextual-kw silent miscompiles:
// a real call you wrote produces nothing useful and no diagnostic.
//
// Reproducer reported by ML_Suite agent (NUC-FEEDBACK-008):
//   tensor_i64_print_flat(...);
//   print("decoded length:");
//   print(text_token_count_i64(&tokens));   // <-- here, exit 1
//
// Fix: at the call site for `print(arg)` with argc == 1, dispatch
// by the static type of arg:
//   - int (i8/i16/i32/i64/isize/u8/.../usize) → __nucleor_print_i64
//   - float (f32/f64)                          → __nucleor_print_f64
//   - bool                                     → __nucleor_print_bool
//   - str / unknown                            → __nucleor_print_str
// (existing default behaviour preserved for str / unknown.)
//
// Returns 42 if all 4 prints land cleanly (the program completes).
// Pre-v0.3.143 returns 139 (SIGSEGV) on the first `print(int_value)`.

fn main() -> i64 {
    let part1: str = str_concat("Hello", " World!");
    print("greeting:");
    print(part1);                  // str — was OK
    print("count:");
    print(42);                     // int literal — was SIGSEGV
    print("computed:");
    let n: i64 = 100 + 23;
    print(n);                      // int var — was SIGSEGV
    print("done");
    return 42;
}
