// EXPECT: MATCH-002 unreachable match arm after wildcard
// Arms after a wildcard never fire.
// err_match_unreachable — RFC-0016 phase 5: MATCH-002 firing.
// Wildcard arm followed by another arm should produce an unreachable warning.
fn main() -> i64 {
    let x: i64 = 5;
    match x {
        1 => { print("one"); },
        _ => { print("any"); },
        2 => { print("never"); },
    };
    return 0;
}
