// rods/capabilities — Capability token catalog
//
// === Capability catalog disclosure ===
//
// The s1 compiler recognizes ONLY `RandomCap` as a
// capability type (verified at `compiler/nucleor_s1_compiler.nr:
// 17115` + `:18315`). Documentation and adopters reading the
// effect/capability RFC may reasonably assume `FsCap`, `NetCap`,
// `TimeCap`, `EnvCap`, `SchedCap` are also enforceable — but
// they are NOT recognized by the s1 type lookup, so a `pure fn`
// requiring `FsCap` is not actually constrained.
//
// This rod exposes `capability_supported(name)`,
// `capabilities_limitations()`, and the catalog names so adopters can
// feature-detect the enforced surface. Future work wires the real
// type-check + capability-token construction surface for Fs / Net /
// Time / Env per RFC.

// Returns 1 if the named capability is recognized + enforced by
// s1's type lookup today, 0 otherwise.
//   - RandomCap: recognized (see compiler:17115).
//   - FsCap / NetCap / TimeCap / EnvCap / SchedCap: NOT recognized
//     (Phase 2 work).
fn capability_supported(name: str) -> i64 {
    if str_eq(name, "RandomCap") == 1 { return 1; };
    // Phase 2 capabilities — explicitly unsupported today:
    if str_eq(name, "FsCap") == 1 { return 0; };
    if str_eq(name, "NetCap") == 1 { return 0; };
    if str_eq(name, "TimeCap") == 1 { return 0; };
    if str_eq(name, "EnvCap") == 1 { return 0; };
    if str_eq(name, "SchedCap") == 1 { return 0; };
    return 0;
}

// Returns the canonical name of the only currently-enforced
// capability. Adopters can use this in conditional code that
// degrades gracefully on Phase 1.
fn capability_only_supported() -> str {
    return "RandomCap";
}

fn capabilities_limitations() -> str {
    return "Capability catalog limitations: (1) ONLY RandomCap is recognized + enforced by the s1 compiler's capability lookup. (2) FsCap, NetCap, TimeCap, EnvCap, SchedCap are NOT recognized — a `pure fn` requiring any of these is not actually constrained at build time, so a Fs/Net/Time/Env/Sched-using helper can leak into a pure context without compile-time error. (3) The corresponding ambient builders (`ambient_fs()`, `ambient_net()`, `ambient_time()`, `ambient_env()`, `ambient_sched()`) are NOT shipped at the rod level and have no runtime symbol. (4) Adopters needing current capability-style sandboxing should use ONLY RandomCap and treat all other capabilities as not-yet-enforced. Future work wires the full catalog with real type-check + capability-token construction.";
}
