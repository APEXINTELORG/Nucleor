// v0.8.296 R10-D4 Phase 1 — cache key rotates when NUCLEOR_INT_STRICT_ARITH flips.
//
// Per audit `BUILD_PLAN_R10_performance_envelope.md` §1 R10-D4 (HIGH):
// pre-v0.8.296 the cache canonical-flags string did NOT include
// `NUCLEOR_INT_STRICT_ARITH`. Flipping the env between builds gave
// stale IR.
//
// This is a SOURCE-LEVEL smoke (rc=0 on simple build); the audit
// behavior verification is via cache-key string contents, exercised
// out-of-band by re-running with the env flipped + observing a
// cache miss. We can't easily inject an env-flip mid-build from a
// .nr fixture, so this fixture just locks the program-shape
// regression.
//
// Cache-key flag semantics (canonical_flags string):
//   dbc-mode=debug;strict-intrin=1;strict-arith=0;strict-mode=fast
//                                  ^^^^^^^^^^^^^^ NEW v0.8.296
// Setting NUCLEOR_INT_STRICT_ARITH=1 flips strict-arith=0 → 1, so
// the SHA256 of the canonical_flags + source body changes,
// invalidating the previous cache entry.
//
// Expected: rc=0; print "ok".

fn main() -> i32 {
    let a: i64 = 5;
    let b: i64 = 3;
    let c: i64 = a + b;
    if c == 8 {
        print("ok");
    } else {
        print("bad");
    };
    return 0;
}
