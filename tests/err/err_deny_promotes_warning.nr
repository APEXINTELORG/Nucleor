// EXPECT: NUM-003 `as` cast loses precision
// `#[deny(NUM-003)]` promotes the lossy-cast warning to an error so
// the build halts. Without the deny, NUM-003 would fire as a warning
// and the build would succeed (see tests/lang/allow_suppress_warning.nr
// for the allow path that silences it).
#[deny(NUM-003)]
fn main() -> i64 {
    let x: i64 = 256;
    let y: i32 = x as i32;
    return 0;
}
