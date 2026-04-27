// t483: v0.4.14 scope-local scrutinee inference for format-macro
// pattern bindings. Closes the common-name conflict that broke
// `format!("got {}", g.field)` when the scrutinee was named `s`
// (declared dozens of times across the bundled source).

pub struct GapReport { severity: i64, message: str }
pub struct PipelineSuccess { pub artifact: str, pub gap_report: Option<GapReport> }

fn hz1_format() -> i64 {
    let r: GapReport = GapReport { severity: 9, message: "io error" };
    let s: PipelineSuccess = PipelineSuccess { artifact: "x", gap_report: Some(r) };
    match s.gap_report {
        None => return 1,
        Some(g) => {
            let formatted: str = format!("got severity={} msg={}", g.severity, g.message);
            if str_eq(formatted, "got severity=9 msg=io error") != 1 { return 1; };
        },
    };
    return 0;
}

fn hz2_result_err() -> i64 {
    let r: Result<i64, str> = Err("bad input");
    match r {
        Ok(v) => return 1,
        Err(e) => {
            let s: str = format!("error: {}", e);
            if str_eq(s, "error: bad input") != 1 { return 1; };
        },
    };
    return 0;
}

fn hz4_option_i64() -> i64 {
    let xi: Option<i64> = Some(42);
    match xi {
        None => return 1,
        Some(vi) => {
            let s: str = format!("vi={}", vi);
            if str_eq(s, "vi=42") != 1 { return 1; };
        },
    };
    return 0;
}

fn main() -> i64 {
    if hz1_format() != 0 { return 1; };
    if hz2_result_err() != 0 { return 2; };
    if hz4_option_i64() != 0 { return 4; };
    return 0;
}
