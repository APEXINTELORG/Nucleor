// v0845 Lane 2 / Queue 2B — same-name method on two impls with distinct
// rows. The substring-search effect enforcement cannot pick which
// `emit` a `p.emit()` call resolves to without AST receiver-type
// resolution (Phase 4). `name_has_distinct_rows_in_table` detects the
// ambiguity and skips the row check, so the legitimate un-rowed call
// to `Pure::emit` does not false-positive against the unrelated rowed
// `Logger::emit`.
//
// Pre-v0845 this fixture's source built with EFF-001 against `caller()`
// because the row check matched `Logger::emit`'s `[io.write]` row when
// scanning for the substring `emit(` in caller's body. v0845 fail-open
// keeps adopter code with same-name methods unblocked. Receiver-type-
// aware resolution is Phase 4 / RFC-0033 broader effect-row subtyping.

struct Pure { tag: i64 }
struct Logger { id: i64 }

impl Pure {
    fn emit(self) -> i32 {
        return 1;
    }
}

impl Logger {
    fn emit(self) -> i32 requires [io.write] {
        print("logger emit");
        return 0;
    }
}

fn caller(p: Pure) -> i32 requires [net] {
    p.emit()
}

fn main() -> i32 requires [net] {
    let p: Pure = Pure { tag: 0 };
    let r: i32 = caller(p);
    if r == 1 { 0 } else { 1 }
}
