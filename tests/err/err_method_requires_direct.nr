// EXPECT: error[EFF-001]
// v0845 Lane 2 / Queue 2B — same-file `impl` method declared with
// `requires [io.write]` is called from a fn declaring `requires [net]`.
// The substring-search call-site check in `enforce_requires_direct_calls`
// matches `l.emit(` in the caller's body and surfaces EFF-001 against
// the method's row.

struct Logger { id: i64 }

impl Logger {
    fn emit(self) -> i32 requires [io.write] {
        print("emit");
        return 0;
    }
}

fn caller(l: Logger) -> i32 requires [net] {
    l.emit()
}

fn main() -> i32 requires [net] {
    let l: Logger = Logger { id: 0 };
    caller(l)
}
