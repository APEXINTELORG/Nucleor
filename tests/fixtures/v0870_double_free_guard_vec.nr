// v0.8.70 RFC-0062 G-4 Phase 2b — Vec double-free guard smoke.
// Run under NUC_VEC_FREE_GUARD=1: triggers PANIC-DOUBLE-FREE
// + exit 134.
//
// Run without the env var (default OFF): silent crash (rc=127
// on Windows access violation).
//
// This fixture documents the v0.8.68 guard contract:
//   guard ON  → reliable detection, clean panic
//   guard OFF → pre-v0.8.68 semantics (silent corruption)

fn main() -> i64 {
    let v: Vec<i64> = Vec::new();
    vec_free(v);
    vec_free(v);  // double free — guard catches under env var
    return 0;     // unreachable under guard
}
