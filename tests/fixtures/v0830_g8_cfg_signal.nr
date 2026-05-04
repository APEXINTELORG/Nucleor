// v0.8.30 RFC-0062 G-8 Phase 2a signal fixture — exercises
// `match` expressions to ensure the CFG-G8 audit-pass info
// fires on a build with multiple match arms.
//
// Build emits `info[CFG-G8]: match expressions in build: N`
// (N>=2; stdlib imports add to the count). rc=6.

fn classify(n: i64) -> i64 {
    return match n {
        0 => 1,
        1 => 2,
        _ => 3,
    };
}

fn weight(n: i64) -> i64 {
    return match n {
        0 => 5,
        _ => 7,
    };
}

fn main() -> i64 {
    // classify(0)=1, weight(2)=7, classify(1)=2, weight(0)=5
    return classify(0) + weight(2) + classify(1) + weight(0) - 9;
    // 1 + 7 + 2 + 5 - 9 = 6
}
