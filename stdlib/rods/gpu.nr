// gpu.nr — GPU compute with safety guardrails
// Works on: NVIDIA, AMD, Intel, integrated GPUs (via Vulkan)
// Falls back to CPU if no GPU or Vulkan not available
// All GPU work runs at low priority — never impacts gaming or normal use

// HON-2: detect whether a Vulkan driver/loader is present on the host.
// This is a *driver-presence* probe, NOT a GPU-compute-readiness check.
// A return of 1 means "a Vulkan driver was found", NOT "GPU acceleration
// will be used" — compute dispatch is still CPU fallback (see
// gpu_backend() / gpu_compute_available()).
fn gpu_available() -> i64 {
    // Cross-platform vulkaninfo probe. The earlier shape used `where ...
    // 2>nul` which is cmd.exe-only — on POSIX `where` is missing so the
    // sh error went to a file literally named `nul` in CWD.
    let probe: str = if str_eq(path_separator(), "\\") == 1 {
        "where vulkaninfo >NUL 2>NUL"
    } else {
        "command -v vulkaninfo >/dev/null 2>/dev/null"
    };
    let rc: i64 = system(probe);
    if rc == 0 { return 1; };
    return 0;
}

// HON-2: honest companion to gpu_available(). Is GPU *compute dispatch*
// actually available today? No — gpu_map / gpu_reduce / gpu_parallel_for
// run as CPU sequential fallbacks regardless of whether a Vulkan driver
// is present. Returns 1 only once real Vulkan shader dispatch is wired
// (Phase 2). Mirrors gpu_op_is_accelerated().
fn gpu_compute_available() -> i64 {
    return 0;
}

// Get GPU device info. HON-2: report the ACTUAL dispatch path, never an
// unconditional "GPU compute available" — even with a Vulkan driver
// present, compute runs on CPU fallback today.
fn gpu_info() -> str {
    if gpu_available() == 0 { return "No Vulkan driver detected; GPU compute runs on CPU fallback (cpu-sequential)."; };
    return "Vulkan driver detected, but GPU compute dispatch is not wired yet — operations run on CPU fallback (cpu-sequential). See gpu_limitations().";
}

// Simple parallel computation on GPU (or CPU fallback)
// Applies fn_ptr to each element in the input array
fn gpu_map(items: Vec<i32>, fn_ptr: i64) -> Vec<i32> {
    let n: i64 = items.len();
    let mut results: Vec<i32> = Vec::new();
    // CPU fallback (always works)
    let mut i: i64 = 0;
    while i < n {
        let fp: i64 = fn_ptr;
        results.push(fp(items.get(i)));
        i = i + 1;
    };
    return results;
}

// Parallel reduce on GPU (or CPU fallback)
fn gpu_reduce(items: Vec<i32>, fn_ptr: i64, initial: i64) -> i64 {
    let n: i64 = items.len();
    let mut acc: i64 = initial;
    let mut i: i64 = 0;
    while i < n {
        let fp: i64 = fn_ptr;
        acc = fp(acc, items.get(i));
        i = i + 1;
    };
    return acc;
}

// Parallel for — execute fn_ptr(i) for i in 0..count
// Uses threading (not GPU) for broad compatibility
fn gpu_parallel_for(fn_ptr: i64, count: i64) -> i64 {
    let ncpu: i64 = cpu_count();
    // Limit thread count to CPU count (never oversubscribe)
    let mut nthreads: i64 = ncpu;
    if nthreads > count { nthreads = count; };
    if nthreads > 8 { nthreads = 8; }; // cap at 8 to leave system headroom
    // Simple: just run sequentially for now
    // Real GPU dispatch requires Vulkan shader compilation
    let mut i: i64 = 0;
    while i < count {
        let fp: i64 = fn_ptr;
        fp(i);
        i = i + 1;
    };
    return count;
}

// Priority control
fn gpu_set_priority(level: str) -> i64 {
    // level: "idle" (default), "low", "normal"
    // Nucleor GPU work defaults to idle — never impacts system
    if str_eq(level, "idle") { return 0; };
    if str_eq(level, "low") { return 1; };
    if str_eq(level, "normal") { return 2; };
    return 0;
}

// === Backend disclosure ===
//
// `gpu_map`, `gpu_reduce`, `gpu_parallel_for` claim GPU acceleration
// in their function names but execute as CPU sequential fallbacks
// today (real Vulkan shader dispatch requires shader compilation
// infrastructure not yet shipped). Adopter calling `gpu_map` could
// reasonably believe their compute ran on the GPU.
//
// `gpu_backend()` returns the current dispatch backend
// ("cpu-sequential" today) so adopters can query before committing
// to a GPU-dependent design. Future work wires real Vulkan
// dispatch and `gpu_backend()` returns "vulkan-compute" when
// available.

// Returns the current backend used for `gpu_map` / `gpu_reduce` /
// `gpu_parallel_for`. As of v0.8.286: always "cpu-sequential" —
// the GPU runtime exists for `gpu_available` (Vulkan probe) but
// the compute primitives have not been wired to Vulkan shader
// dispatch yet. Adopters needing real GPU acceleration today must
// drop down to the Vulkan FFI directly or wait for Phase 2.
fn gpu_backend() -> str {
    return "cpu-sequential";
}

// Returns 1 if the named operation is GPU-accelerated today;
// 0 if it falls back to CPU. As of v0.8.286 all three return 0.
fn gpu_op_is_accelerated(op: str) -> i64 {
    // Explicit names for clarity — Phase 2 returns 1 when wired.
    if str_eq(op, "gpu_map") == 1 { return 0; };
    if str_eq(op, "gpu_reduce") == 1 { return 0; };
    if str_eq(op, "gpu_parallel_for") == 1 { return 0; };
    return 0;
}

fn gpu_limitations() -> str {
    return "GPU compute limitations: (1) gpu_map/gpu_reduce/gpu_parallel_for execute as CPU sequential fallbacks; no Vulkan shader dispatch despite `gpu_available()` reporting Vulkan present. (2) gpu_set_priority maps to a stable integer code but does NOT actually adjust GPU scheduler priority — future work wires this when the Vulkan VK_EXT_global_priority extension is available. (3) No memory transfer primitives (no buffer alloc, no host<->device copy) — adopter cannot stream tensors across PCIe yet. Query gpu_backend() for current dispatch path. Future work wires real GPU dispatch + memory transfer + priority hints.";
}
