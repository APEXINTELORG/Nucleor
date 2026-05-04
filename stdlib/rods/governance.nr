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

// =====================================================
// v0.7.79 — RFC-0060 Phase 2b: PolicyDecl + check_policies
//
// The governance rod's policy surface. Adopters declare intent
// (`governance_declare_policy("no_unsafe")`) and downstream tooling
// (`nuc gov policy`, custom audit scripts) reads back the declared
// policies via the count/get pair.
//
// `governance_check_policies(source)` does a rod-level pre-flight
// substring check that mirrors a subset of the compiler-side
// `source_rule_check` pass (GOV-001 / GOV-002 + no_extern). This is
// for adopters who want to validate a source string in-process
// before calling `nuc build`; the canonical enforcement still runs
// in the compiler tool-suite at build time.
// =====================================================

extern fn nuc_gov_register_policy(name: str, severity: str) -> i64;
extern fn nuc_gov_policy_count() -> i64;
extern fn nuc_gov_policy_name(idx: i64) -> str;
extern fn nuc_gov_policy_severity(idx: i64) -> str;
extern fn nuc_gov_policy_clear() -> i64;
extern fn nuc_gov_check_source(source: str) -> i64;

struct PolicyDecl {
    name: str,
    severity: str,
}

fn governance_policy(name: str) -> PolicyDecl {
    return PolicyDecl { name: name, severity: "deny" };
}

fn governance_policy_full(name: str, severity: str) -> PolicyDecl {
    return PolicyDecl { name: name, severity: severity };
}

fn governance_declare_policy(p: PolicyDecl) -> i64 {
    return nuc_gov_register_policy(p.name, p.severity);
}

fn governance_policy_count() -> i64 {
    return nuc_gov_policy_count();
}

fn governance_policy_get(idx: i64) -> PolicyDecl {
    return PolicyDecl {
        name:     nuc_gov_policy_name(idx),
        severity: nuc_gov_policy_severity(idx),
    };
}

fn governance_policy_clear() -> i64 {
    return nuc_gov_policy_clear();
}

fn governance_check_policies(source: str) -> i64 {
    return nuc_gov_check_source(source);
}

fn governance_policy_to_json(p: PolicyDecl) -> str {
    let mut out: str = "{\"name\":\"";
    out = str_concat(out, _gov_json_escape(p.name));
    out = str_concat(out, "\",\"severity\":\"");
    out = str_concat(out, _gov_json_escape(p.severity));
    out = str_concat(out, "\"}");
    return out;
}

fn governance_policy_all_to_json() -> str {
    let n: i64 = governance_policy_count();
    let mut out: str = "[";
    let mut i: i64 = 0;
    while i < n {
        if i > 0 { out = str_concat(out, ","); };
        out = str_concat(out, governance_policy_to_json(governance_policy_get(i)));
        i = i + 1;
    };
    out = str_concat(out, "]");
    return out;
}
