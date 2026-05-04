// rods/enclave — RFC-0057 Phase A: enclave types + info-flow
// label surface (rod-only).
//
// The full RFC-0057 ship adds language-level `Secret<T>` /
// `Public<T>` / `Confidential<T>` / `ExportControlled<T>` info-
// flow labels + `@enclave(engine)` placement attribute +
// `@attested` quote-emit attribute (~700 LOC compiler + ~900
// LOC stdlib + per-vendor attestation parsers). Phase A (this
// rod + runtime) lands the canonical type tags + enclave
// engine registry + secret-wrap/declassify audit log adopters
// can use today.
//
// Sister to RFC-0052 / 53 / 54 / 55 / 56 Phase A — sixth V2
// frontier Tier-B follow-on after the Tier-A close-out at
// v0.7.90.
//
// Workflow today:
//
//   import "stdlib/rods/enclave.nr"
//
//   let h: i64 = enclave_create(enclave_engine_tdx());
//   let quote: AttestationQuote = enclave_attest(h);
//   let s: SecretHandle = secret_wrap(42, info_flow_secret());
//   let v: i64 = declassify(s, "user_consent_v3");
//   enclave_close(h);

#cfile "../runtime/enclave_rt.c"

extern fn nuc_enclave_create(engine_id: i64) -> i64;
extern fn nuc_enclave_close(handle: i64) -> i64;
extern fn nuc_enclave_count() -> i64;
extern fn nuc_enclave_engine(handle: i64) -> i64;
extern fn nuc_enclave_attest(handle: i64) -> i64;
extern fn nuc_enclave_verify_quote(quote_id: i64, want_measurement: i64) -> i64;
extern fn nuc_secret_wrap(value: i64, label: i64) -> i64;
extern fn nuc_secret_label(handle: i64) -> i64;
extern fn nuc_secret_unwrap_in_enclave(secret_h: i64, enclave_h: i64) -> i64;
extern fn nuc_secret_declassify(secret_h: i64, justification: str) -> i64;
extern fn nuc_secret_declassify_log_count() -> i64;
extern fn nuc_secret_declassify_log_get(idx: i64) -> str;
extern fn nuc_secret_clear() -> i64;

// =====================================================
// Enclave engine tags (stable IDs).
// =====================================================
fn enclave_engine_tdx()              -> i64 { return 1; }   // Intel TDX
fn enclave_engine_sev_snp()          -> i64 { return 2; }   // AMD SEV-SNP
fn enclave_engine_secure_enclave()   -> i64 { return 3; }   // Apple Secure Enclave
fn enclave_engine_h100_confidential() -> i64 { return 4; }  // NVIDIA H100 confidential
fn enclave_engine_arm_cca()          -> i64 { return 5; }   // Arm CCA
fn enclave_engine_software()         -> i64 { return 6; }   // CPU-only software-attested fallback
fn enclave_engine_unknown()          -> i64 { return 0; }

fn enclave_engine_name(id: i64) -> str {
    if id == 1 { return "TDX"; };
    if id == 2 { return "SEV-SNP"; };
    if id == 3 { return "SecureEnclave"; };
    if id == 4 { return "H100Confidential"; };
    if id == 5 { return "ArmCCA"; };
    if id == 6 { return "Software"; };
    return "Unknown";
}

// =====================================================
// Info-flow label tags (stable IDs).
// =====================================================
fn info_flow_public()             -> i64 { return 1; }
fn info_flow_confidential()       -> i64 { return 2; }
fn info_flow_secret()             -> i64 { return 3; }
fn info_flow_export_controlled()  -> i64 { return 4; }

fn info_flow_label_name(id: i64) -> str {
    if id == 1 { return "Public"; };
    if id == 2 { return "Confidential"; };
    if id == 3 { return "Secret"; };
    if id == 4 { return "ExportControlled"; };
    return "Unknown";
}

// Two labels are flow-compatible if `from` is at most as
// sensitive as `to`. Public can flow anywhere; Secret only into
// Secret. ExportControlled is treated as Secret-equivalent for
// outflow checks. Phase B promotes to type-level enforcement;
// Phase A adopters call this manually at sink boundaries.
fn info_flow_can_flow(from: i64, to: i64) -> i64 {
    if from == info_flow_public() { return 1; };
    if from == info_flow_confidential() {
        if to == info_flow_confidential() { return 1; };
        if to == info_flow_secret() { return 1; };
        return 0;
    };
    if from == info_flow_secret() {
        if to == info_flow_secret() { return 1; };
        return 0;
    };
    if from == info_flow_export_controlled() {
        if to == info_flow_export_controlled() { return 1; };
        return 0;
    };
    return 0;
}

// Mixing-promotion: when two labels combine in an expression,
// the result has the more-sensitive label.
fn info_flow_promote(a: i64, b: i64) -> i64 {
    if a == info_flow_export_controlled() { return a; };
    if b == info_flow_export_controlled() { return b; };
    if a == info_flow_secret() { return a; };
    if b == info_flow_secret() { return b; };
    if a == info_flow_confidential() { return a; };
    if b == info_flow_confidential() { return b; };
    return info_flow_public();
}

// =====================================================
// EnclaveHandle / AttestationQuote / SecretHandle.
// =====================================================
struct EnclaveHandle { handle: i64, engine: i64 }

fn enclave_create(engine_id: i64) -> EnclaveHandle {
    let h: i64 = nuc_enclave_create(engine_id);
    return EnclaveHandle { handle: h, engine: engine_id };
}

fn enclave_close(e: EnclaveHandle) -> i64 {
    return nuc_enclave_close(e.handle);
}

fn enclave_count() -> i64 { return nuc_enclave_count(); }

fn enclave_engine(e: EnclaveHandle) -> i64 { return e.engine; }

struct AttestationQuote { quote_id: i64, engine: i64 }

fn enclave_attest(e: EnclaveHandle) -> AttestationQuote {
    let q: i64 = nuc_enclave_attest(e.handle);
    return AttestationQuote { quote_id: q, engine: e.engine };
}

fn enclave_verify_quote(q: AttestationQuote, want_measurement: i64) -> i64 {
    return nuc_enclave_verify_quote(q.quote_id, want_measurement);
}

struct SecretHandle { handle: i64, label: i64 }

fn secret_wrap(value: i64, label: i64) -> SecretHandle {
    let h: i64 = nuc_secret_wrap(value, label);
    return SecretHandle { handle: h, label: label };
}

fn secret_label(s: SecretHandle) -> i64 { return s.label; }

// Inside-enclave unwrap: returns the raw value WITHOUT logging
// when the enclave handle is valid. Phase A trusts the caller;
// Phase B's @enclave attribute auto-injects this at body-entry.
fn secret_unwrap_in_enclave(s: SecretHandle, e: EnclaveHandle) -> i64 {
    return nuc_secret_unwrap_in_enclave(s.handle, e.handle);
}

// declassify: sanctioned downgrade with audit log entry. The
// justification string is stored in the runtime's append-only
// log so adopter audit pipelines can replay the chain.
fn declassify(s: SecretHandle, justification: str) -> i64 {
    return nuc_secret_declassify(s.handle, justification);
}

fn declassify_log_count() -> i64 { return nuc_secret_declassify_log_count(); }
fn declassify_log_get(idx: i64) -> str { return nuc_secret_declassify_log_get(idx); }

fn secret_clear() -> i64 { return nuc_secret_clear(); }
