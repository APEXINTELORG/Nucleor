// v0845 Lane 2 / Queue 2B — positive smoke for same-file `impl` method
// `requires [...]` row covering. Caller and main both declare
// `requires [io.write]` matching the method's row. Build must succeed
// and the program must print "emit ok" then exit 0.

struct Logger { id: i64 }

impl Logger {
    fn emit(self) -> i32 requires [io.write] {
        print("emit ok");
        return 0;
    }
}

fn caller(l: Logger) -> i32 requires [io.write] {
    l.emit()
}

fn main() -> i32 requires [io.write] {
    let l: Logger = Logger { id: 0 };
    caller(l)
}
