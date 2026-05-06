// EXPECT: error[EFF-003]
// Block-form restricts is not yet enforced by s1; it must fail loudly
// instead of implying compile-time effect guarantees.

fn main() -> i32 {
    restricts [io] {
        print_int(1);
        0
    }
}
