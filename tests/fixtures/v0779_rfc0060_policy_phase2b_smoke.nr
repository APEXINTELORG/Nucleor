// v0.7.79 RFC-0060 Phase 2b smoke fixture — PolicyDecl + declare +
// check_policies. Verifies the rod-level surface is callable and the
// substring check correctly counts violations against a declared
// policy set.
import "stdlib/rods/governance.nr"

fn main() -> i64 {
    governance_policy_clear();

    let p1: PolicyDecl = governance_policy("no_unsafe");
    let p2: PolicyDecl = governance_policy_full("require_authored", "warn");
    let p3: PolicyDecl = governance_policy("no_extern");

    governance_declare_policy(p1);
    governance_declare_policy(p2);
    governance_declare_policy(p3);

    let n: i64 = governance_policy_count();
    if n != 3 { return 1; };

    let g0: PolicyDecl = governance_policy_get(0);
    if str_eq(g0.name, "no_unsafe") == 0 { return 2; };
    if str_eq(g0.severity, "deny") == 0 { return 3; };

    let g1: PolicyDecl = governance_policy_get(1);
    if str_eq(g1.severity, "warn") == 0 { return 4; };

    let clean: str = "fn main() -> i64 { return 0; }";
    let v_clean: i64 = governance_check_policies(clean);
    if v_clean != 1 { return 5; };

    let dirty: str = "extern fn raw(x: i64) -> i64; fn main() -> i64 { unsafe { return 0; }; }";
    let v_dirty: i64 = governance_check_policies(dirty);
    if v_dirty < 2 { return 6; };

    let json: str = governance_policy_all_to_json();
    if str_len(json) < 10 { return 7; };

    governance_policy_clear();
    if governance_policy_count() != 0 { return 8; };

    return 0;
}
