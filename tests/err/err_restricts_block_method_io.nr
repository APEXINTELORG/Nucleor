// EXPECT: error[EFF-003]
// v0845 Lane 2 / Queue 2B — `restricts [io.write] { obj.method(); }`
// where the method body transitively reaches io.write via builtin
// `print`. `restricts_transitive_check` walks the method body via
// the resolved single source and trips on the deny row.

struct Sink { tag: i64 }

impl Sink {
    fn dump(self) -> i32 {
        print("dump");
        return 0;
    }
}

fn main() -> i32 {
    let s: Sink = Sink { tag: 0 };
    restricts [io.write] {
        let _r: i32 = s.dump();
    };
    return 0;
}
