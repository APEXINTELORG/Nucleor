// EXPECT: TNT-001 tainted value flows into sensitive sink
// Lane 3 (F-DIAG-006 / F-DIAG-010): TNT-001 must be emitted by the
// main compiler when an explicitly tainted value flows into a sensitive
// sink without sanitize(...).

fn run_query(q: tainted<str>) -> i64 {
    print(q);
    return 0;
}

fn main() -> i64 {
    let raw: tainted<str> = "select * from user_input";
    return run_query(raw);
}
