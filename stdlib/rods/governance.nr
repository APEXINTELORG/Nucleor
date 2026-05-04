// rods/governance — RFC-0060 Phase 2a: optional governance rod.
//
// Provides a process-local registry of authorship records that any
// downstream tool (`nuc evidence`, `nuc audit`, `nuc gov`) can query.
// The s1 compiler sees nothing — programs that don't import this rod
// pay zero cost.
//
// Phase 2a (this ship): AuthorRecord + register/query/to_json.
// Phase 2b (next): PolicyDecl + check_policies (wires to source_rule_check).
// Phase 2c (later): SchemaDecl + EvidenceBundle + sign/verify.

#cfile "../runtime/governance_rt.c"

extern fn nuc_gov_register_authored(by: str, tool: str, date: str, commit: str, review: str) -> i64;
extern fn nuc_gov_authored_count() -> i64;
extern fn nuc_gov_authored_by(idx: i64) -> str;
extern fn nuc_gov_authored_tool(idx: i64) -> str;
extern fn nuc_gov_authored_date(idx: i64) -> str;
extern fn nuc_gov_authored_commit(idx: i64) -> str;
extern fn nuc_gov_authored_review(idx: i64) -> str;
extern fn nuc_gov_clear() -> i64;

struct AuthorRecord {
    by: str,
    tool: str,
    date: str,
    commit: str,
    review: str,
}

fn governance_authored(by: str, tool: str, date: str) -> AuthorRecord {
    return AuthorRecord { by: by, tool: tool, date: date, commit: "", review: "" };
}

fn governance_authored_full(by: str, tool: str, date: str, commit: str, review: str) -> AuthorRecord {
    return AuthorRecord { by: by, tool: tool, date: date, commit: commit, review: review };
}

fn governance_register_authored(rec: AuthorRecord) -> i64 {
    return nuc_gov_register_authored(rec.by, rec.tool, rec.date, rec.commit, rec.review);
}

fn governance_authored_count() -> i64 {
    return nuc_gov_authored_count();
}

fn governance_authored_get(idx: i64) -> AuthorRecord {
    return AuthorRecord {
        by:     nuc_gov_authored_by(idx),
        tool:   nuc_gov_authored_tool(idx),
        date:   nuc_gov_authored_date(idx),
        commit: nuc_gov_authored_commit(idx),
        review: nuc_gov_authored_review(idx),
    };
}

fn governance_clear() -> i64 {
    return nuc_gov_clear();
}

fn _gov_json_escape(s: str) -> str {
    return s;
}

fn governance_authored_to_json(rec: AuthorRecord) -> str {
    let mut out: str = "{\"by\":\"";
    out = str_concat(out, _gov_json_escape(rec.by));
    out = str_concat(out, "\",\"tool\":\"");
    out = str_concat(out, _gov_json_escape(rec.tool));
    out = str_concat(out, "\",\"date\":\"");
    out = str_concat(out, _gov_json_escape(rec.date));
    out = str_concat(out, "\",\"commit\":\"");
    out = str_concat(out, _gov_json_escape(rec.commit));
    out = str_concat(out, "\",\"review\":\"");
    out = str_concat(out, _gov_json_escape(rec.review));
    out = str_concat(out, "\"}");
    return out;
}

fn governance_authored_all_to_json() -> str {
    let n: i64 = governance_authored_count();
    let mut out: str = "[";
    let mut i: i64 = 0;
    while i < n {
        if i > 0 { out = str_concat(out, ","); };
        out = str_concat(out, governance_authored_to_json(governance_authored_get(i)));
        i = i + 1;
    };
    out = str_concat(out, "]");
    return out;
}
