// EXPECT: nucleor: print() takes exactly 1 arg (got 0
// v0.4.121: bare `print()` (no args) was silently lowered to
// __nucleor_print_str(garbage_ptr), SIGSEGV at runtime. Sister
// to v0.4.35 (print >1 arg): same hazard class — adopter typo
// or leftover-after-arg-deletion got runtime crash with no
// compile-time signal. Now halts cleanly at lower-time.

fn main() -> i32 {
    print();
    0
}
