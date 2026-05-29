// v0.8.191 stdlib/rods/governance.nr first test coverage.
//
// RFC-0060 Phase 2a — optional governance rod, AuthorRecord
// registry. Pre-v0.8.191: zero coverage on the runtime API.
//
// Locks five textbook registry invariants:
//   1. Empty registry: count == 0 after clear.
//   2. Register + count: registering an AuthorRecord
//      increments count by 1.
//   3. Round-trip via get: registered record's fields read
//      back exactly.
//   4. JSON serialization: output contains all 5 fields.
//   5. Authored constructor: bare form leaves commit/review
//      empty.
//
// Expected: rc=0.

import "stdlib/rods/governance.nr"
import "stdlib/rods/strings.nr"

fn check_empty() -> i64 {
    governance_clear();
    if governance_authored_count() != 0 { return 1; };
    return 0;
}

fn check_register_and_count() -> i64 {
    governance_clear();
    let rec: AuthorRecord = governance_authored("Maintainer", "review-tool", "2026-05-05");
    governance_register_authored(rec);
    if governance_authored_count() != 1 { return 2; };
    return 0;
}

fn check_round_trip() -> i64 {
    governance_clear();
    let rec: AuthorRecord = governance_authored_full(
        "Maintainer", "review-tool", "2026-05-05", "commit_abc123", "review_xyz789"
    );
    governance_register_authored(rec);
    let got: AuthorRecord = governance_authored_get(0);
    if str_eq(got.by, "Maintainer") != 1 { return 4; };
    if str_eq(got.tool, "review-tool") != 1 { return 8; };
    if str_eq(got.date, "2026-05-05") != 1 { return 16; };
    if str_eq(got.commit, "commit_abc123") != 1 { return 32; };
    if str_eq(got.review, "review_xyz789") != 1 { return 64; };
    return 0;
}

fn check_json_serialization() -> i64 {
    let rec: AuthorRecord = governance_authored("Alice", "tool_x", "2026-05-05");
    let json: str = governance_authored_to_json(rec);
    // Verify all 5 keys appear
    if strings_index_of(json, "\"by\":") < 0 { return 128; };
    if strings_index_of(json, "\"tool\":") < 0 { return 256; };
    if strings_index_of(json, "\"date\":") < 0 { return 512; };
    if strings_index_of(json, "\"commit\":") < 0 { return 1024; };
    if strings_index_of(json, "\"review\":") < 0 { return 2048; };
    if strings_index_of(json, "Alice") < 0 { return 4096; };
    return 0;
}

fn check_bare_constructor_empty() -> i64 {
    let rec: AuthorRecord = governance_authored("X", "y", "2026-05-05");
    if str_eq(rec.commit, "") != 1 { return 8192; };
    if str_eq(rec.review, "") != 1 { return 16384; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_empty();
    fails = fails + check_register_and_count();
    fails = fails + check_round_trip();
    fails = fails + check_json_serialization();
    fails = fails + check_bare_constructor_empty();
    return fails;
}
