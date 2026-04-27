// Probe v0.4.12: Option<MyStruct> as a struct field
// (the exact Translate PipelineSuccess.gap_report shape).
pub struct GapReport {
    severity: i64,
    message: str,
}
pub struct PipelineSuccess {
    pub artifact: str,
    pub gap_report: Option<GapReport>,
}

fn main() -> i64 {
    let r: GapReport = GapReport { severity: 5, message: "warn" };
    let s: PipelineSuccess = PipelineSuccess { artifact: "out.bin", gap_report: Some(r) };
    match s.gap_report {
        None => return 1,
        Some(g) => {
            if g.severity != 5 { return 1; };
            if str_eq(g.message, "warn") != 1 { return 1; };
        },
    };
    let s_none: PipelineSuccess = PipelineSuccess { artifact: "ok.bin", gap_report: None };
    match s_none.gap_report {
        None => return 0,
        Some(g) => return 1,
    };
}
