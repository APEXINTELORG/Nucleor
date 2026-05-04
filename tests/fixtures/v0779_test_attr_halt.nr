// v0.7.79 negative fixture — Rust `#[test]` attribute halt.
// Pre-fix the attribute was silently dropped at lex and the fn
// parsed as a regular fn — DCE then elided un-called test fns
// and adopters silently lost their entire test suite without
// diagnostic. Now halts at lex with a workaround pointer (call
// test fns from main or use the verify.ps1 fixtures harness).
// Sister to v0.7.18 inline/cold attribute halts.
#[test]
fn test_basic() {
    return;
}

fn main() -> i64 { return 0; }
