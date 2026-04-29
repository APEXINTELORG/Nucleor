// Phase 3a: Comprehensive overflow behavior test
fn main() -> i32 {
    // === WRAPPING MODE ===
    // Addition overflow wraps
    let w1: i32 = wrapping { 2147483647 + 1 };
    print_int(w1);  // -2147483648

    // Subtraction underflow wraps
    let w2: i32 = wrapping { 0 - 2147483647 - 2 };
    print_int(w2);  // 2147483647 (wraps around)

    // Multiplication overflow wraps
    let w3: i32 = wrapping { 100000 * 100000 };
    print_int(w3);  // wraps (1410065408)

    // === SATURATING MODE ===
    // Addition saturates at MAX
    let s1: i32 = saturating { 2147483647 + 100 };
    print_int(s1);  // 2147483647

    // Subtraction saturates at MIN
    let s2: i32 = saturating { 0 - 2147483647 - 100 };
    print_int(s2);  // -2147483648

    // Normal arithmetic still works
    let s3: i32 = saturating { 10 + 20 };
    print_int(s3);  // 30

    // === DEFAULT (TRAP) MODE ===
    // Normal arithmetic under default trap mode works fine
    let t1: i32 = 100 + 200;
    print_int(t1);  // 300

    let t2: i32 = 50 * 40;
    print_int(t2);  // 2000

    // === NESTED MODES ===
    // Wrapping inside saturating
    let n1: i32 = saturating {
        let a: i32 = wrapping { 2147483647 + 1 };  // wraps to -2147483648
        a + 1  // saturating: -2147483648 + 1 = -2147483647 (no overflow, no sat)
    };
    print_int(n1);  // -2147483647

    0
}
