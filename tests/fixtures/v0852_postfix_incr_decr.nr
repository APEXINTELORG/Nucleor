// v0.8.46 fixture: postfix ++ / -- increment/decrement
// Verifies that x++ desugars to x = x + 1 and x-- to x = x - 1.

fn main() -> i64 {
    let mut i: i64 = 0;
    i++;
    i++;
    i++;
    // i should now be 3
    if i != 3 { return 1; };

    i--;
    // i should now be 2
    if i != 2 { return 2; };

    // Works in a loop body (common C-translation pattern)
    let mut count: i64 = 0;
    let mut n: i64 = 10;
    while n > 0 {
        n--;
        count++;
    };
    // count should be 10, n should be 0
    if count != 10 { return 3; };
    if n != 0 { return 4; };

    // Works on field access expressions
    // (same LHS shapes as += / -= which are already supported)
    return 0;
}
