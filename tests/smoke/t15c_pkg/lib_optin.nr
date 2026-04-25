// Has at least one pub fn → T1.5c privatization opt-in active.
// `lib_helper` becomes private; cross-module callers can't see it.
pub fn lib_pub_api() -> i64 { return lib_helper() + 100; }
fn lib_helper() -> i64 { return 7; }
