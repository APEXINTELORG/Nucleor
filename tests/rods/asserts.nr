// rods/asserts — verify rod wrapper
import "stdlib/rods/asserts.nr"

fn main() -> i64 {
    check(1);
    check_eq(2 + 2, 4);
    check_ne(1, 2);
    check_with(1, "should not fire");
    print("OK asserts");
    return 0;
}
