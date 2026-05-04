// rods/target_caps — RFC-0048 Phase A: hardware capability queries.
//
// The RFC-0048 thesis: kernels conditionally using FP4 / FP8 /
// BF16 / SVE / AVX-512 / tensor cores need a way to ask "does
// this build target support FP4?" at COMPILE time, not at
// runtime via dynamic dispatch (which costs perf and code size).
// The full ship parses `if target.has(FP4) { ... }` as a
// compile-time-resolved branch with DCE on the dead arm
// (~300 LOC compiler-side).
//
// Phase A (this rod) lands the canonical query surface as RUNTIME
// fns that return a stable i64 (1 = available, 0 = not). Today
// every device-class feature returns 0 (Nucleor v0.7 has no
// GPU / SIMD / accelerator dispatch yet); host-class features
// (OS family, arch family) return real values via the existing
// os_info rod's `os_family()` builtin. Adopters writing
// `if target_caps_has_fp4() == 1 { ... }` get the canonical
// surface today; Phase B replaces the runtime call with
// compile-time const-fold + dead-branch DCE.
//
// Sister to RFC-0046 / RFC-0047 / RFC-0049 Phase A landings —
// same "stdlib first, compiler enforcement later" pattern.

import "stdlib/rods/os_info.nr"

// =====================================================
// Capability IDs (stable across rod versions). Adopters can
// store / serialize the integer ID; the matching fn name maps
// 1:1.
// =====================================================
fn target_cap_id_fp4()           -> i64 { return 1; }
fn target_cap_id_fp8()           -> i64 { return 2; }
fn target_cap_id_bf16()          -> i64 { return 3; }
fn target_cap_id_avx2()          -> i64 { return 10; }
fn target_cap_id_avx512()        -> i64 { return 11; }
fn target_cap_id_neon()          -> i64 { return 12; }
fn target_cap_id_sve()           -> i64 { return 13; }
fn target_cap_id_tensor_cores()  -> i64 { return 20; }
fn target_cap_id_cuda()          -> i64 { return 21; }
fn target_cap_id_vulkan()        -> i64 { return 22; }
fn target_cap_id_rocm()          -> i64 { return 23; }
fn target_cap_id_metal()         -> i64 { return 24; }

// =====================================================
// Per-cap query fns. Phase A: every device-class feature returns
// 0 because Nucleor v0.7 has no GPU / SIMD / accelerator dispatch
// substrate. Phase B replaces these bodies with const-fold against
// the build manifest (CLI `--target-feature=fp4,avx512,...`).
// Adopter code stays identical — only the resolution mechanism
// changes.
// =====================================================
fn target_caps_has_fp4()           -> i64 { return 0; }
fn target_caps_has_fp8()           -> i64 { return 0; }
fn target_caps_has_bf16()          -> i64 { return 0; }
fn target_caps_has_avx2()          -> i64 { return 0; }
fn target_caps_has_avx512()        -> i64 { return 0; }
fn target_caps_has_neon()          -> i64 { return 0; }
fn target_caps_has_sve()           -> i64 { return 0; }
fn target_caps_has_tensor_cores()  -> i64 { return 0; }
fn target_caps_has_cuda()          -> i64 { return 0; }
fn target_caps_has_vulkan()        -> i64 { return 0; }
fn target_caps_has_rocm()          -> i64 { return 0; }
fn target_caps_has_metal()         -> i64 { return 0; }

// =====================================================
// OS / arch family queries. These are real — backed by the
// existing os_info rod's runtime detection.
// =====================================================
fn target_caps_os_windows()  -> i64 { return os_is_windows(); }
fn target_caps_os_linux()    -> i64 { return os_is_linux(); }
fn target_caps_os_macos()    -> i64 { return os_is_macos(); }
fn target_caps_os_bsd()      -> i64 { return os_is_bsd(); }
fn target_caps_os_unix()     -> i64 { return os_is_unix(); }

// Arch family. Phase A only knows pointer-width; arch detection
// (x86_64 vs aarch64 vs riscv64) is host-runtime info Nucleor
// doesn't yet expose. Returns 0 for all explicit arches; adopters
// branch on os_family + pointer_width as a stand-in until Phase B.
fn target_caps_arch_x86_64()    -> i64 { return 0; }
fn target_caps_arch_aarch64()   -> i64 { return 0; }
fn target_caps_arch_riscv64()   -> i64 { return 0; }
fn target_caps_is_64bit()       -> i64 { return os_is_64bit(); }

// =====================================================
// Generic query by ID. Useful for table-driven kernels that
// loop over known caps and call this once per ID.
// =====================================================
fn target_caps_has_id(id: i64) -> i64 {
    if id == 1  { return target_caps_has_fp4(); };
    if id == 2  { return target_caps_has_fp8(); };
    if id == 3  { return target_caps_has_bf16(); };
    if id == 10 { return target_caps_has_avx2(); };
    if id == 11 { return target_caps_has_avx512(); };
    if id == 12 { return target_caps_has_neon(); };
    if id == 13 { return target_caps_has_sve(); };
    if id == 20 { return target_caps_has_tensor_cores(); };
    if id == 21 { return target_caps_has_cuda(); };
    if id == 22 { return target_caps_has_vulkan(); };
    if id == 23 { return target_caps_has_rocm(); };
    if id == 24 { return target_caps_has_metal(); };
    return 0;
}

fn target_caps_id_name(id: i64) -> str {
    if id == 1  { return "fp4"; };
    if id == 2  { return "fp8"; };
    if id == 3  { return "bf16"; };
    if id == 10 { return "avx2"; };
    if id == 11 { return "avx512"; };
    if id == 12 { return "neon"; };
    if id == 13 { return "sve"; };
    if id == 20 { return "tensor_cores"; };
    if id == 21 { return "cuda"; };
    if id == 22 { return "vulkan"; };
    if id == 23 { return "rocm"; };
    if id == 24 { return "metal"; };
    return "unknown";
}
