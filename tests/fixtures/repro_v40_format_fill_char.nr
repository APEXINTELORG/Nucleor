// v0.4.40 RFC-0028 phase 5 — custom fill char (already worked since
// v0.4.29; this fixture pins it so it can't regress).
fn main() -> i64 {
    let n: i64 = 42;
    let s: str = "hi";

    // Numeric — fill with '*'
    println!("[{:*<10}]", n);    // [42********]   (left-align, *-fill)
    println!("[{:*>10}]", n);    // [********42]   (right-align, *-fill)
    println!("[{:*^10}]", n);    // [****42****]   (center, *-fill)

    // String — fill with '-'
    println!("[{:-<8}]", s);     // [hi------]
    println!("[{:->8}]", s);     // [------hi]

    // Mixed precision + custom fill
    let pi: f64 = 3.14159;
    println!("[{:.<10.3}]", pi); // [3.142.....]   (left-align, .-fill, prec 3)

    return 0;
}
