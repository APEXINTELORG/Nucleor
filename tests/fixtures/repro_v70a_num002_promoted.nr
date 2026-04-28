// repro_v70a_num002_promoted.nr — v0.4.70 audit section 1 partial.
// NUM-002 (literal-out-of-range) promoted from warning to error.
// `let x: u8 = 256;` was a silent truncate to 0 with only a warning;
// now hard error.

fn main() -> i64 {
    let x: u8 = 256;   // NUM-002 expected
    return 0;
}
