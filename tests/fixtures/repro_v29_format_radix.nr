// v0.4.29 RFC-0028 phase 5 — radix specs (x/X/o/b) + alternate form (#)
fn main() -> i64 {
    let n: i64 = 255;
    let m: i64 = 8;
    let k: i64 = 10;

    // Bare radix
    println!("{:x}", n);     // expect ff
    println!("{:X}", n);     // expect ff (no upper-casing yet — still hex digits)
    println!("{:o}", m);     // expect 10
    println!("{:b}", k);     // expect 1010

    // Alternate form (prefix 0x / 0o / 0b)
    println!("{:#x}", n);    // expect 0xff
    println!("{:#o}", m);    // expect 0o10
    println!("{:#b}", k);    // expect 0b1010

    // Combination: width + radix
    println!("[{:>8x}]", n); // expect [      ff]
    println!("[{:<8x}]", n); // expect [ff      ]
    println!("[{:08x}]", n); // expect [000000ff]

    return 0;
}
