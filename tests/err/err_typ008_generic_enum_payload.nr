// EXPECT: error[TYP-008]
// Audit pass 1 Layer 2 F-006: Holder<i64>::Some requires an i64 payload.
enum Holder<T> { Some(T), None }

fn main() -> i32 {
    let h: Holder<i64> = Holder::Some("hello");
    print_int(0);
    0
}
