// EXPECT: error[NR023] chained assignment
// v0.4.111: chained assignment `a = b = c` is rejected at parse
// time. Pre-fix Nucleor's parser silently dropped the trailing
// `= c` portion, leaving both a and b at their pre-assignment
// values (most often 0). Adopters writing the C/Java idiom got
// silent-miscompute output (`a == 0, b == 0` instead of
// `a == 5, b == 5`). NR023 panics from parse_stmt's assignment
// branch when a `=` token follows the RHS expression.

fn main() -> i32 {
    let mut a: i32 = 0;
    let mut b: i32 = 0;
    a = b = 5;
    print_int(a);
    print_int(b);
    0
}
