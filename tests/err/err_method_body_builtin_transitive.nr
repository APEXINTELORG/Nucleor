// EXPECT: error[EFF-001]
// v0845 Lane 2 / Queue 2B — same-file `impl` method body calls the
// io.write builtin `print` directly. The method has no row. Caller
// declares `requires [net]`. The bounded transitive scan reaches
// io.write through the method body and emits EFF-001 transitive.

struct Sink { tag: i64 }

impl Sink {
    fn dump(self) -> i32 {
        print("dump");
        return 0;
    }
}

fn caller(s: Sink) -> i32 requires [net] {
    s.dump()
}

fn main() -> i32 requires [net] {
    let s: Sink = Sink { tag: 0 };
    caller(s)
}
