// EXPECT: error[NR022] no `fn main()` defined
// v0.4.110: lift the no-main-fn link error (Windows LNK1561 /
// POSIX `undefined reference to main`) to a clean NR022
// diagnostic. Pre-fix users saw clang's cryptic
// `LINK : fatal error LNK1561: entry point must be defined`
// line and the `linker command failed with exit code 1561`
// note — adopters had to know what LNK1561 means. Same lift
// pattern as v0.4.106's TYP-005 lift.

fn helper() -> i32 {
    42
}
