// v0.8.9 Phase B step-2 smoke fixture — extract the actual
// author names from `@authored("name", "tool", "date")`
// attributes. Three tagged fns with different authors. Build
// emits:
//   audit: @authored fns in build: 3
//   audit:   authors: alice; bob; automation
// rc = 6 (1 + 2 + 3).

@authored("alice", "review-tool", "2026-05-04")
fn audited_a() -> i64 { return 1; }

@authored("bob", "review-tool", "2026-05-04")
fn audited_b() -> i64 { return 2; }

@authored("automation", "review-tool", "2026-05-04")
fn audited_c() -> i64 { return 3; }

fn main() -> i64 {
    return audited_a() + audited_b() + audited_c();
}
