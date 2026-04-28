// v0.4.37 RFC-0028 phase 5: `{:X}` upper-case hex digits.
// Pre-fix: `:X` produced same lowercase output as `:x`. Post-fix: upper.
fn main() -> i64 {
    let n: i64 = 255;
    let m: i64 = 4015;  // 0xFAF
    println!("{:x}", n);    // expect ff
    println!("{:X}", n);    // expect FF
    println!("{:x}", m);    // expect faf
    println!("{:X}", m);    // expect FAF
    // Combination: alt form + upper
    println!("{:#X}", n);   // expect 0xFF (alt prefix stays "0x", payload upper)
    return 0;
}
