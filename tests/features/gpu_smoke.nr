// v0.8.192 stdlib/rods/gpu.nr first test coverage.
//
// GPU compute (Vulkan-backed) + CPU fallback with low-priority
// guardrails. Pre-v0.8.192: zero coverage on the standalone gpu
// rod surface.
//
// Locks two invariants — the rod is mostly fn-pointer-driven so
// most of the surface needs callback support. Lock the
// host-environment query path:
//
//   1. **gpu_available returns 0 or 1** (host-state predicate).
//   2. **gpu_info returns non-empty string** describing state.
//   3. **gpu_compute_available returns 0** (HON-2: compute dispatch is
//      CPU fallback today regardless of driver presence — asserts the
//      rod does not over-claim GPU acceleration).
//
// Expected: rc=0.

import "stdlib/rods/gpu.nr"

fn check_gpu_available_predicate() -> i64 {
    let avail: i64 = gpu_available();
    if avail != 0 {
        if avail != 1 { return 1; };
    };
    return 0;
}

fn check_gpu_info_non_empty() -> i64 {
    let s: str = gpu_info();
    if str_len(s) == 0 { return 2; };
    return 0;
}

// HON-2: lock the honesty invariant — GPU compute dispatch is not wired,
// so gpu_compute_available() must report 0 until real Vulkan dispatch
// lands. Prevents silently re-introducing the "GPU compute available"
// over-claim.
fn check_gpu_compute_not_overclaimed() -> i64 {
    if gpu_compute_available() != 0 { return 4; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_gpu_available_predicate();
    fails = fails + check_gpu_info_non_empty();
    fails = fails + check_gpu_compute_not_overclaimed();
    return fails;
}
