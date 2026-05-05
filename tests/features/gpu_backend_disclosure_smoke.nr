// v0.8.286 R08-D4 Phase 1 — GPU backend disclosure.
//
// Per audit `BUILD_PLAN_R08_tensor_ml_autodiff.md` §1 R08-D4 (HIGH):
// `gpu_map`, `gpu_reduce`, `gpu_parallel_for` execute as CPU
// sequential fallbacks despite their names suggesting GPU
// dispatch. Phase 1 ships `gpu_backend()` returning the current
// dispatch backend ("cpu-sequential" today) and
// `gpu_op_is_accelerated(name)` returning per-op truth, plus a
// `gpu_limitations()` text helper.
//
// Phase 2 wires real Vulkan shader dispatch and `gpu_backend()`
// returns "vulkan-compute" when available.
//
// Phase 1 acceptance:
//   - backend query returns "cpu-sequential";
//   - per-op accelerated query returns 0 for all three known ops;
//   - limitations helper returns non-empty string naming key gaps.
//
// Locks 5 invariants:
//   1. **Backend is `cpu-sequential`** today.
//   2. **`gpu_map` is NOT accelerated** today.
//   3. **`gpu_reduce` is NOT accelerated** today.
//   4. **`gpu_parallel_for` is NOT accelerated** today.
//   5. **Limitations string names "Vulkan"** so adopters know the
//      target backend that's still being wired.
//
// Expected: rc=0.

import "stdlib/rods/gpu.nr"

fn check_backend() -> i64 {
    let b: str = gpu_backend();
    if str_eq(b, "cpu-sequential") != 1 { return 1; };
    return 0;
}

fn check_map_not_accel() -> i64 {
    if gpu_op_is_accelerated("gpu_map") != 0 { return 2; };
    return 0;
}

fn check_reduce_not_accel() -> i64 {
    if gpu_op_is_accelerated("gpu_reduce") != 0 { return 4; };
    return 0;
}

fn check_pfor_not_accel() -> i64 {
    if gpu_op_is_accelerated("gpu_parallel_for") != 0 { return 8; };
    return 0;
}

fn check_limitations_names_vulkan() -> i64 {
    let s: str = gpu_limitations();
    if str_len(s) == 0 { return 16; };
    if str_index_of(s, "Vulkan") < 0 { return 32; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_backend();
    fails = fails + check_map_not_accel();
    fails = fails + check_reduce_not_accel();
    fails = fails + check_pfor_not_accel();
    fails = fails + check_limitations_names_vulkan();
    return fails;
}
