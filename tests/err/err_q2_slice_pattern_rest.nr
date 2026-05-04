// EXPECT: slice patterns with rest binding
// Q2 lock-in — v0.8.34. The slice-pattern halt now fires with
// a slice-pattern-specific diagnostic instead of the wrong-class
// range-expression message. Locks the new diagnostic.

fn main() -> i64 {
    let arr: Vec<i64> = Vec::new();
    match &arr[..] {
        [a, .., b] => return *a + *b,  // ERROR: slice rest pattern
        _ => return 0,
    };
}
