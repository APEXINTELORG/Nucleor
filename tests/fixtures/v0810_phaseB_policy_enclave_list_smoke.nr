// v0.8.10 Phase B step-2 smoke fixture — extract the actual
// policy + enclave-engine names from @policy(...) and
// @enclave(<engine>) attributes. Build emits:
//   audit: @enclave fns in build: 2
//   audit:   engines: tdx; sev_snp
//   audit: @policy decls in build: 3
//   audit:   policies: no_unsafe; require_authored; no_extern
// rc = 5.

@policy(no_unsafe)
fn p1() -> i64 { return 1; }

@policy(require_authored)
fn p2() -> i64 { return 1; }

@policy(no_extern)
fn p3() -> i64 { return 1; }

@enclave(tdx)
fn e1() -> i64 { return 1; }

@enclave(sev_snp)
fn e2() -> i64 { return 1; }

fn main() -> i64 {
    return p1() + p2() + p3() + e1() + e2();
}
