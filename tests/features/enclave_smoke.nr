// v0.8.188 stdlib/rods/enclave.nr first test coverage.
//
// RFC-0057 Phase A — enclave types + info-flow label surface
// (rod-only). Sister to v0.8.147 RFC-0048 frontier audit.
// Pre-v0.8.188: zero coverage on the runtime API.
//
// Locks five textbook info-flow + enclave invariants:
//
//   1. **Engine ID stable**: TDX=1, SEV-SNP=2, Apple=3, etc.
//   2. **Engine name round-trip**: name(1) == "TDX".
//   3. **Info-flow lattice — Public flows everywhere**.
//   4. **Info-flow lattice — Secret only flows to Secret** (not
//      to Public or Confidential).
//   5. **Promote takes max** — promote(Public, Secret) == Secret.
//
// Expected: rc=0.

import "stdlib/rods/enclave.nr"

fn check_engine_ids() -> i64 {
    if enclave_engine_tdx() != 1 { return 1; };
    if enclave_engine_sev_snp() != 2 { return 2; };
    if enclave_engine_secure_enclave() != 3 { return 4; };
    if enclave_engine_h100_confidential() != 4 { return 8; };
    if enclave_engine_arm_cca() != 5 { return 16; };
    if enclave_engine_software() != 6 { return 32; };
    if enclave_engine_unknown() != 0 { return 64; };
    return 0;
}

fn check_engine_name() -> i64 {
    if str_eq(enclave_engine_name(1), "TDX") != 1 { return 128; };
    if str_eq(enclave_engine_name(2), "SEV-SNP") != 1 { return 256; };
    if str_eq(enclave_engine_name(99), "Unknown") != 1 { return 512; };
    return 0;
}

fn check_public_flows_everywhere() -> i64 {
    let pub_id: i64 = info_flow_public();
    if info_flow_can_flow(pub_id, info_flow_public()) != 1 { return 1024; };
    if info_flow_can_flow(pub_id, info_flow_confidential()) != 1 { return 2048; };
    if info_flow_can_flow(pub_id, info_flow_secret()) != 1 { return 4096; };
    return 0;
}

fn check_secret_only_to_secret() -> i64 {
    let sec_id: i64 = info_flow_secret();
    if info_flow_can_flow(sec_id, info_flow_public()) != 0 { return 8192; };
    if info_flow_can_flow(sec_id, info_flow_confidential()) != 0 { return 16384; };
    if info_flow_can_flow(sec_id, info_flow_secret()) != 1 { return 32768; };
    return 0;
}

fn check_promote_takes_max() -> i64 {
    if info_flow_promote(info_flow_public(), info_flow_secret()) != info_flow_secret() { return 65536; };
    if info_flow_promote(info_flow_secret(), info_flow_public()) != info_flow_secret() { return 131072; };
    if info_flow_promote(info_flow_export_controlled(), info_flow_secret()) != info_flow_export_controlled() { return 262144; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_engine_ids();
    fails = fails + check_engine_name();
    fails = fails + check_public_flows_everywhere();
    fails = fails + check_secret_only_to_secret();
    fails = fails + check_promote_takes_max();
    return fails;
}
