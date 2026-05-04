// rods/memspace — RFC-0049 Phase A: memory-space type tags.
//
// The RFC-0049 thesis: heterogeneous-hardware programs need to know
// WHICH memory pool a tensor lives in (HBM on GPU, DDR on host, CXL
// fabric, on-die scratchpad SRAM, NPU SRAM). Wrong-pool ops should
// fail at type-check, not silently DMA-then-crunch.
//
// The full RFC-0049 ship phantom-types `Tensor<T, Space>` with
// type-checker enforcement of co-location across `matmul` /
// `convolve` / etc. operations (~200 LOC compiler + ~150 LOC
// stdlib). Phase A (this rod) lands the canonical zero-size
// MemSpace_* marker structs + numeric ID surface for adopters who
// want to tag their tensor wrappers today, ahead of Phase B
// compiler enforcement.
//
// Sister to RFC-0046 Phase A (kinematics_frame markers) and
// RFC-0047 Phase A (7-vector dim surface in units.nr) — same
// "phantom-typed via stdlib first, compiler enforcement later"
// pattern.
//
// Workflow today:
//
//   import "stdlib/rods/memspace.nr"
//
//   // Tag your tensor wrappers in your own struct definitions:
//   struct HBMTensor { handle: i64, shape: [i64; 4], space: MemSpace_HBM }
//   struct DDRTensor { handle: i64, shape: [i64; 4], space: MemSpace_DDR }
//
//   // Or as runtime metadata via the numeric ID surface:
//   let s: i64 = memspace_id_hbm();        // returns 1
//   let s2: i64 = memspace_id_ddr();       // returns 2

struct MemSpace_Default {}
struct MemSpace_HBM {}
struct MemSpace_DDR {}
struct MemSpace_CXL {}
struct MemSpace_Scratchpad {}
struct MemSpace_NPU_SRAM {}
struct MemSpace_GPU_Shared {}
struct MemSpace_Pinned {}
struct MemSpace_Unified {}

// Numeric ID surface. IDs are stable across rod versions; -1 is
// reserved for "unknown / not yet set".
fn memspace_id_default()    -> i64 { return 0; }
fn memspace_id_hbm()        -> i64 { return 1; }
fn memspace_id_ddr()        -> i64 { return 2; }
fn memspace_id_cxl()        -> i64 { return 3; }
fn memspace_id_scratchpad() -> i64 { return 4; }
fn memspace_id_npu_sram()   -> i64 { return 5; }
fn memspace_id_gpu_shared() -> i64 { return 6; }
fn memspace_id_pinned()     -> i64 { return 7; }
fn memspace_id_unified()    -> i64 { return 8; }
fn memspace_id_unknown()    -> i64 { return 0 - 1; }

fn memspace_name(id: i64) -> str {
    if id == 0 { return "default"; };
    if id == 1 { return "hbm"; };
    if id == 2 { return "ddr"; };
    if id == 3 { return "cxl"; };
    if id == 4 { return "scratchpad"; };
    if id == 5 { return "npu_sram"; };
    if id == 6 { return "gpu_shared"; };
    if id == 7 { return "pinned"; };
    if id == 8 { return "unified"; };
    return "unknown";
}

// Two memspaces are compatible if they're the same OR one is
// MemSpace_Default OR one is unknown. matmul-style co-location
// helpers should call this to gate cross-pool operands until
// Phase B enforcement lands.
fn memspace_compatible(a: i64, b: i64) -> i64 {
    if a == b { return 1; };
    if a == 0 { return 1; };
    if b == 0 { return 1; };
    if a == 0 - 1 { return 1; };
    if b == 0 - 1 { return 1; };
    return 0;
}

// True iff the memspace is a host-RAM-class pool (DDR, pinned,
// unified-memory). Useful for runtime fallback dispatch — every
// memspace currently lowers to host malloc in v0.7.x; Phase B and
// the GPU-runtime ship promote HBM / scratchpad to real device pools.
fn memspace_is_host_class(id: i64) -> i64 {
    if id == 2 { return 1; };
    if id == 7 { return 1; };
    if id == 8 { return 1; };
    if id == 0 { return 1; };
    return 0;
}

// True iff the memspace is a device-class pool (HBM, scratchpad,
// NPU SRAM, GPU shared, CXL fabric). All currently fall back to
// host RAM with a runtime warning per RFC-0049 design — Phase B
// wires the actual device-pool dispatch.
fn memspace_is_device_class(id: i64) -> i64 {
    if id == 1 { return 1; };
    if id == 3 { return 1; };
    if id == 4 { return 1; };
    if id == 5 { return 1; };
    if id == 6 { return 1; };
    return 0;
}
