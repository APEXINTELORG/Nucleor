import "stdlib/rods/ml/cert_facade.nr"

fn main() -> i64 {
    let manifest = cert_profile_manifest(
        "unsigned_cert_profile_smoke",
        "do178c_iso26262_iec62304_ready",
        "none_unsigned_smoke",
        "deterministic_replay_required",
        "audit_trace_required",
        0,
        1,
        1,
        1,
        1,
        1,
        0
    );

    cert_profile_manifest_print(&manifest);
    cert_profile_manifest_emit_jsonl(&manifest);
    cert_profile_manifest_emit_status(1);
    if cert_native_available() != 0 { panic("cert_facade falsely advertises a native backend"); };
    return 0;
}
