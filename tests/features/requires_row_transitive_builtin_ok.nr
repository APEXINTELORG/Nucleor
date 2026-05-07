// R05-D6 v0844 positive smoke: family root `io` permits the transitive
// helper call chain that reaches `print_int` (`io.write`).

fn helper_write() -> i32 {
    print_int(65);
    0
}

fn caller() -> i32 requires [io] {
    helper_write()
}

fn main() -> i32 requires [io] {
    caller()
}
