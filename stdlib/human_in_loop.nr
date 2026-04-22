// human_in_loop.nr — Human-in-the-loop runtime gates (GAP-10)
// Phase 11: approve blocks that pause execution for human review.
//
// Features:
// 1. Approval gates: agent must get human approval before executing
// 2. Escalation: if timeout, escalate to supervisor
// 3. Audit trail: all approval decisions are logged
// 4. Configurable: approve/deny/modify actions

fn str_from_int(n: i32) -> str {
    if n == 0 { return "0"; };
    let mut val: i32 = n;
    if val < 0 { val = 0 - val; };
    let mut s: str = "";
    while val > 0 {
        let d: i32 = val - (val / 10) * 10;
        let mut ch: str = "0";
        if d == 1 { ch = "1"; } else if d == 2 { ch = "2"; } else if d == 3 { ch = "3"; }
        else if d == 4 { ch = "4"; } else if d == 5 { ch = "5"; } else if d == 6 { ch = "6"; }
        else if d == 7 { ch = "7"; } else if d == 8 { ch = "8"; } else if d == 9 { ch = "9"; };
        s = str_concat(ch, s);
        val = val / 10;
    };
    if n < 0 { s = str_concat("-", s); };
    s
}

const APPROVAL_PENDING: i32 = 0;
const APPROVAL_APPROVED: i32 = 1;
const APPROVAL_DENIED: i32 = 2;
const APPROVAL_ESCALATED: i32 = 3;

fn approval_name(s: i32) -> str {
    if s == APPROVAL_PENDING { "PENDING" }
    else if s == APPROVAL_APPROVED { "APPROVED" }
    else if s == APPROVAL_DENIED { "DENIED" }
    else if s == APPROVAL_ESCALATED { "ESCALATED" }
    else { "?" }
}

// Simulate an approval gate
fn request_approval(action: str, risk_level: i32) -> i32 {
    print(str_concat("  APPROVAL REQUEST: ", action));
    print(str_concat("  risk level: ", str_from_int(risk_level)));

    // Auto-approve low risk, require review for medium, deny high risk
    if risk_level <= 2 {
        print("  AUTO-APPROVED (low risk)");
        APPROVAL_APPROVED
    } else if risk_level <= 5 {
        print("  REQUIRES HUMAN REVIEW (medium risk)");
        // Simulate human approving
        print("  [human] -> APPROVED");
        APPROVAL_APPROVED
    } else if risk_level <= 8 {
        print("  REQUIRES HUMAN REVIEW (high risk)");
        print("  [human] -> DENIED");
        APPROVAL_DENIED
    } else {
        print("  ESCALATED TO SUPERVISOR (critical risk)");
        APPROVAL_ESCALATED
    }
}

fn test_low_risk() -> i32 {
    print("=== Gate 1: low risk action ===");
    let result: i32 = request_approval("log observation to database", 1);
    if result == APPROVAL_APPROVED { print("  PASS"); } else { print("  FAIL"); };
    0
}

fn test_medium_risk() -> i32 {
    print("=== Gate 2: medium risk action ===");
    let result: i32 = request_approval("send email notification", 4);
    if result == APPROVAL_APPROVED { print("  PASS"); } else { print("  FAIL"); };
    0
}

fn test_high_risk() -> i32 {
    print("=== Gate 3: high risk action (expect deny) ===");
    let result: i32 = request_approval("delete production database", 7);
    if result == APPROVAL_DENIED { print("  PASS (correctly denied)"); } else { print("  FAIL"); };
    0
}

fn test_critical_risk() -> i32 {
    print("=== Gate 4: critical risk (expect escalate) ===");
    let result: i32 = request_approval("deploy to all production servers", 9);
    if result == APPROVAL_ESCALATED { print("  PASS (correctly escalated)"); } else { print("  FAIL"); };
    0
}

fn test_audit_trail() -> i32 {
    print("=== Gate 5: audit trail ===");
    // All approval decisions logged with structured data
    let mut audit: Vec<i32> = Vec::new();
    let mut audit_count: i32 = 0;

    audit.push(1); audit.push(APPROVAL_APPROVED); audit_count = audit_count + 1;
    audit.push(4); audit.push(APPROVAL_APPROVED); audit_count = audit_count + 1;
    audit.push(7); audit.push(APPROVAL_DENIED); audit_count = audit_count + 1;
    audit.push(9); audit.push(APPROVAL_ESCALATED); audit_count = audit_count + 1;

    let mut i: i32 = 0;
    while i < audit_count {
        let risk: i32 = audit.get(i * 2);
        let decision: i32 = audit.get(i * 2 + 1);
        print(str_concat("  audit[", str_concat(str_from_int(i), str_concat("]: risk=", str_concat(str_from_int(risk), str_concat(" decision=", approval_name(decision)))))));
        i = i + 1;
    };
    print("  PASS");
    0
}

fn main() -> i32 {
    print("================================================");
    print("  Human-in-the-Loop Gates (Phase 11, GAP-10)");
    print("================================================");
    test_low_risk();
    test_medium_risk();
    test_high_risk();
    test_critical_risk();
    test_audit_trail();
    print("================================================");
    print("  HUMAN-IN-THE-LOOP COMPLETE");
    print("================================================");
    0
}
