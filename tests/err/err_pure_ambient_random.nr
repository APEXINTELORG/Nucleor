// EXPECT: error[EFF-001]
// v0.8.309 R05-D4 Phase 1 — fixture mode corrected.
// Pre-v0.8.307 the s1 build path did not emit EFF-001, so this
// test relied on a downstream LINK failure (`__nucleor_ambient_random`
// undefined at clang link). v0.8.307 wired pure-fn purity into
// the s1 diagnostic pipeline; v0.8.308 consolidated it into the
// single-walk pass. The fixture now correctly fires
// `error[EFF-001]: 'pure fn bad' uses ambient capability (ambient_*)
//  — non-deterministic input is not pure; ...`.
//
// Audit R05-D4 acceptance: fixture fails for effect violation, not
// linker symbol absence.

pure fn bad() -> i32 {
    let rng: RandomCap = ambient_random();
    let _keep: RandomCap = rng;
    0
}

fn main() -> i32 {
    bad()
}
