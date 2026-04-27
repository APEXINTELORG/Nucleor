// Probe v0.4.11: Option<MyStruct> propagation through let-assign
// + struct-field access on the bound payload.
pub struct GapReport {
    severity: i64,
    message: str,
}

fn main() -> i64 {
    let report: GapReport = GapReport { severity: 7, message: "missing capability" };
    let gr: Option<GapReport> = Some(report);

    match gr {
        None => return 1,
        Some(g) => {
            // Direct field access on the bound struct payload --
            // this requires __type_g = "GapReport", not "i64".
            if g.severity != 7 { return 1; };
            if str_eq(g.message, "missing capability") != 1 { return 1; };
        },
    };

    let none_case: Option<GapReport> = None;
    match none_case {
        None => return 0,
        Some(g) => return 1,
    };
}
