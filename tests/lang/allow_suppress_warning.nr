// `#[allow(CODE)]` post-filter — suppresses NUM-003 lossy-cast warning
// (v0.2.151; minimal file-wide allow scope, full per-fn / per-block
// scoping ships with v0.4 attribute parsing).
//
// The build prints "OK allow_suppress_warning" if the cast is allowed
// without warning noise. Without the `#[allow]` line above main, the
// build would print a NUM-003 warning before this OK line.

#[allow(NUM-003)]
fn main() -> i64 {
    let x: i64 = 256;
    let y: i32 = x as i32;
    print("OK allow_suppress_warning");
    return 0;
}
