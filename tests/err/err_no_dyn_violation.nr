// EXPECT: RT-003 dynamic dispatch
// T3.6 (v0.3.5) negative — fn marked #[no_dyn] whose signature
// declares `&dyn Trait`. The v1 text scan fires on the `dyn `
// token inside the parameter list. v0.3.6 strips strings/comments
// from the body before scanning, so this fixture deliberately
// puts the offending token in the SIGNATURE (which v0.3.6 keeps
// scanning verbatim).

trait Sensor {}

#[no_dyn]
fn poll(s: &dyn Sensor) -> i64 {
    return 0;
}

fn main() -> i64 {
    return 0;
}
