// EXPECT: error[EFF-001]
// R05-D6 v0844: standalone `requires [...]` row enforcement walks
// bounded same-file un-rowed helper chains. The caller declares `net`,
// but the helper reaches `print_int` (`io.write`).

fn helper_write() -> i32 {
    print_int(65);
    0
}

fn caller() -> i32 requires [net] {
    helper_write()
}

fn main() -> i32 requires [net] {
    caller()
}
