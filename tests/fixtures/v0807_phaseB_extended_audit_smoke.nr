// v0.8.7 Phase B step-1 — extended attribute audit smoke
// fixture. Tags 7 fns across 7 attribute families. Build emits
// 7 audit summary lines:
//   audit: @photonic fns in build: 1
//   audit: @neuromorphic fns in build: 1
//   audit: @enclave fns in build: 1
//   audit: @attested fns in build: 1
//   audit: @authored fns in build: 2
//   audit: @policy decls in build: 1
//   audit: @within timing constraints in build: 1
// rc = 7 (one fn per family, each returns 1).

@photonic[device=lightmatter_x1]
fn optical_layer() -> i64 { return 1; }

@neuromorphic[device=loihi2]
fn snn_inference() -> i64 { return 1; }

@enclave(tdx)
fn process_pii() -> i64 { return 1; }

@attested(quote_required=true)
fn handshake() -> i64 { return 1; }

@authored("alice", "claude", "2026-05-04")
fn audited_fn_a() -> i64 { return 1; }

@authored("bob", "claude", "2026-05-04")
fn audited_fn_b() -> i64 { return 1; }

@policy(no_unsafe)
fn policy_gated() -> i64 { return 1; }

@within(200ns)
fn timed_seq() -> i64 { return 1; }

fn main() -> i64 {
    return optical_layer()
         + snn_inference()
         + process_pii()
         + handshake()
         + audited_fn_a()
         + policy_gated()
         + timed_seq();
}
