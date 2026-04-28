// repro_v70b_format_arg_count.nr — v0.4.70 audit section 10 partial.
// Pre-fix `println!("{} and {}", 42)` rendered "42 and <MISSING>" at
// runtime — silent wrong output. v0.4.70 panics at preprocess.

fn main() -> i64 {
    println!("{} and {}", 42);   // panic expected
    return 0;
}
