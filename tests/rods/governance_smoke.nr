// rods/governance — RFC-0060 Phase 2a smoke
import "stdlib/rods/governance.nr"

fn main() -> i64 {
    governance_clear();

    let r1: AuthorRecord = governance_authored("joseph_wescott", "human", "2026-05-03");
    let r2: AuthorRecord = governance_authored_full(
        "claude-opus-4.7", "claude-code", "2026-05-03", "ef3d45cc", "joseph_wescott"
    );

    let i1: i64 = governance_register_authored(r1);
    let i2: i64 = governance_register_authored(r2);
    if i1 != 0 { print("FAIL i1"); return 1; };
    if i2 != 1 { print("FAIL i2"); return 1; };

    let n: i64 = governance_authored_count();
    if n != 2 { print("FAIL count"); return 1; };

    let g1: AuthorRecord = governance_authored_get(0);
    if str_eq(g1.by, "joseph_wescott") != 1 { print("FAIL g1.by"); return 1; };
    if str_eq(g1.tool, "human") != 1 { print("FAIL g1.tool"); return 1; };
    if str_eq(g1.date, "2026-05-03") != 1 { print("FAIL g1.date"); return 1; };

    let g2: AuthorRecord = governance_authored_get(1);
    if str_eq(g2.tool, "claude-code") != 1 { print("FAIL g2.tool"); return 1; };
    if str_eq(g2.commit, "ef3d45cc") != 1 { print("FAIL g2.commit"); return 1; };
    if str_eq(g2.review, "joseph_wescott") != 1 { print("FAIL g2.review"); return 1; };

    let json: str = governance_authored_all_to_json();
    print(json);
    print("OK governance_smoke");
    return 0;
}
