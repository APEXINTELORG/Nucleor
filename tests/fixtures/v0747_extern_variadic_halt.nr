// v0.7.47 negative fixture — C-FFI variadic `extern "C" fn printf(fmt, ...)`
// halts cleanly (was wrong-class NR020 expected `:`, got token 45).
extern "C" fn printf(fmt: str, ...);
fn main() -> i64 { return 0; }
