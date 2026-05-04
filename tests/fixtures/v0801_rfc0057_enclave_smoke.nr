// v0.8.1 RFC-0057 Phase A smoke fixture — enclave types +
// info-flow label surface. Validates:
//   - Enclave engine tags + name lookup
//   - Info-flow label tags + flow predicates
//   - flow_promote returns the more-sensitive label
//   - Enclave create / attest / verify_quote round-trip
//   - Secret wrap + label read-back
//   - In-enclave unwrap retrieves raw value
//   - declassify produces value + appends to audit log
//   - Multiple declassify entries log in order
import "stdlib/rods/enclave.nr"

fn main() -> i64 {
    secret_clear();

    // Engine tags.
    if enclave_engine_tdx() != 1 { return 1; };
    if enclave_engine_sev_snp() != 2 { return 2; };
    if enclave_engine_h100_confidential() != 4 { return 3; };
    if str_eq(enclave_engine_name(1), "TDX") == 0 { return 4; };
    if str_eq(enclave_engine_name(99), "Unknown") == 0 { return 5; };

    // Info-flow labels.
    if info_flow_public() != 1 { return 6; };
    if info_flow_secret() != 3 { return 7; };
    if str_eq(info_flow_label_name(3), "Secret") == 0 { return 8; };

    // Flow predicates.
    if info_flow_can_flow(info_flow_public(), info_flow_secret()) != 1 { return 9; };
    if info_flow_can_flow(info_flow_secret(), info_flow_public()) != 0 { return 10; };
    if info_flow_can_flow(info_flow_secret(), info_flow_secret()) != 1 { return 11; };
    if info_flow_can_flow(info_flow_export_controlled(), info_flow_secret()) != 0 { return 12; };
    if info_flow_can_flow(info_flow_confidential(), info_flow_secret()) != 1 { return 13; };
    if info_flow_can_flow(info_flow_confidential(), info_flow_public()) != 0 { return 14; };

    // Promote: more-sensitive wins.
    if info_flow_promote(info_flow_public(), info_flow_secret()) != info_flow_secret() { return 15; };
    if info_flow_promote(info_flow_confidential(), info_flow_secret()) != info_flow_secret() { return 16; };
    if info_flow_promote(info_flow_export_controlled(), info_flow_secret()) != info_flow_export_controlled() { return 17; };
    if info_flow_promote(info_flow_public(), info_flow_public()) != info_flow_public() { return 18; };

    // Enclave create + attest.
    let e: EnclaveHandle = enclave_create(enclave_engine_tdx());
    if enclave_engine(e) != enclave_engine_tdx() { return 19; };
    if enclave_count() != 1 { return 20; };

    let q: AttestationQuote = enclave_attest(e);
    if q.engine != enclave_engine_tdx() { return 21; };
    if enclave_verify_quote(q, 0xDEAD) != 1 { return 22; };

    // Quote-id 0 (no attest yet) doesn't verify.
    let bad_q: AttestationQuote = AttestationQuote { quote_id: 0, engine: enclave_engine_tdx() };
    if enclave_verify_quote(bad_q, 0xDEAD) != 0 { return 23; };

    // Secret wrap + label.
    let s1: SecretHandle = secret_wrap(42, info_flow_secret());
    if secret_label(s1) != info_flow_secret() { return 24; };

    // In-enclave unwrap.
    let v: i64 = secret_unwrap_in_enclave(s1, e);
    if v != 42 { return 25; };

    // Declassify with audit.
    let s2: SecretHandle = secret_wrap(99, info_flow_confidential());
    let raw: i64 = declassify(s2, "user_consent_v3");
    if raw != 99 { return 26; };

    // Audit log captures the justification.
    if declassify_log_count() != 1 { return 27; };
    if str_eq(declassify_log_get(0), "user_consent_v3") == 0 { return 28; };

    // Second declassify appends.
    let s3: SecretHandle = secret_wrap(7, info_flow_secret());
    declassify(s3, "compliance_review_2026q2");
    if declassify_log_count() != 2 { return 29; };
    if str_eq(declassify_log_get(1), "compliance_review_2026q2") == 0 { return 30; };

    enclave_close(e);
    secret_clear();
    if declassify_log_count() != 0 { return 31; };

    return 0;
}
