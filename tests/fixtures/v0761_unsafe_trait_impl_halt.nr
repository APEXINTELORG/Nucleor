// v0.7.61 negative fixture — `unsafe trait` halts cleanly (was
// silent-stripped sister to v0.6.53 unsafe fn halt).
unsafe trait T { fn m(self) -> i64; }
fn main() -> i64 { return 0; }
