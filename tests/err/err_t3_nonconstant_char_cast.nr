// EXPECT: error[TYP-026]
// T-3 v0845: non-constant `as char` must prove scalar-range safety first.

fn main() -> i64 {
    let v: i64 = args_count();
    let c: char = v as char;
    return 0;
}
