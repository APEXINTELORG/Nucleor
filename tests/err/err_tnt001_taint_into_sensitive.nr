// EXPECT: TNT-001 tainted value flows into sensitive sink
// Lane 3 (F-DIAG-006 / F-DIAG-010): TNT-001 has a suggestion entry
// in the auto-suggestion table at compiler/nucleor_s1_compiler.nr:10709
// but no actual `diag_add_ex(... "TNT-001" ...)` emit path. This
// fixture documents the expected diagnostic so the negative-coverage
// gate flags TNT-001 as uncovered (not silently ghosted) until the
// taint checker is wired post-Lane-3.

extern fn read_user_input() -> str;

fn run_query(q: str) -> i64 {
    // sensitive sink — should require sanitize() upstream.
    print(q);
    return 0;
}

fn main() -> i64 {
    let raw: str = read_user_input();
    return run_query(raw);
}
