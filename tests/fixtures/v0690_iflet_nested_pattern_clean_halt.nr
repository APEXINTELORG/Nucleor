// v0.6.90 (defensive halt): canonical Rust nested pattern in
// `if let` / `while let` (e.g. `if let Some(Some(v)) = opt`,
// `if let Ok(Some(v)) = res`) pre-fix surfaced as wrong-class
// `error[NR020]: expected ')', got '('` because the parser reads
// the binding slot as a single ident and then expects `)`. Now
// halts cleanly with a 2-step-destructure workaround pointer.
// Negative fixture (compile rejects). Sister to nested struct
// pattern halt (line ~1364) and parse_match_one_pattern's
// equivalent guard.
fn main() -> i32 {
    let opt: Option<Option<i64>> = Some(Some(42));
    if let Some(Some(v)) = opt {    // ← halts: nested pattern unsupported
        print_int(v as i32);
    }
    return 0;
}
