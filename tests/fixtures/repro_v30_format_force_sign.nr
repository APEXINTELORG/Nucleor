// v0.4.30 RFC-0028 phase 5 — `{:+}` force-sign on integers
fn main() -> i64 {
    let pos: i64 = 42;
    let neg: i64 = 0 - 7;
    let zero: i64 = 0;

    println!("{:+}", pos);    // expect +42
    println!("{:+}", neg);    // expect -7
    println!("{:+}", zero);   // expect +0

    // Combination with width
    println!("[{:>+6}]", pos); // expect [   +42]
    println!("[{:<+6}]", pos); // expect [+42   ]

    // Plain spec (no force) for contrast
    println!("{}", pos);      // expect 42

    return 0;
}
