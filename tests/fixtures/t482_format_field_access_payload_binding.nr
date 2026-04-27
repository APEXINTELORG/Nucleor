pub struct GapReport { severity: i64, message: str }
pub struct Wrap { pub gap: Option<GapReport> }
fn main() -> i64 {
    let r: GapReport = GapReport { severity: 7, message: "missing capability" };
    let w: Wrap = Wrap { gap: Some(r) };
    match w.gap {
        None => println!("no gap"),
        Some(g) => {
            println!("severity={}", g.severity);
            println!("message={}", g.message);
        },
    };
    return 0;
}
