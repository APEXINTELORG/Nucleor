// EXPECT: error[EFF-001]
// R05-D6 v0844: standalone `requires [...]` rows now check known
// direct builtin effects in the function body. `print_int` is `io.write`,
// so a function declaring only `requires [net]` must fail.

fn bad_write() -> i32 requires [net] {
    print_int(65);
    0
}

fn main() -> i32 requires [net] {
    bad_write()
}
