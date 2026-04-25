// 22_rt_export.nr — C-callable kernel via #[export].
//
// Production robotics middleware (ROS, microROS, RTI Connext,
// custom EtherCAT masters, embedded boot loaders) typically
// owns the main loop and wants to call into Nucleor for one
// RT-tight kernel at a time. The v0.3.4 #[export] surface +
// `nuc gen-headers` gives those callers an unmangled C
// signature without any FFI glue.
//
// Three #[export] kernels here:
//   * nuc_scale (Vec3, f64) -> Vec3   — struct-in / struct-out
//   * nuc_add   (i64, i64)  -> i64    — scalar-only
//   * nuc_print_dot (Vec3, Vec3) -> i64 — struct-in, side-effect out
//
// The #[repr(C)] struct matches the C ABI byte-for-byte, so
// the host C side just `#include "kernel.h"` and calls into
// the Nucleor-built `.o` directly.
//
// To produce the matching C header:
//
//     nuc gen-headers examples/22_rt_export.nr -o kernel.h
//
// The header will declare:
//
//     typedef struct Vec3 { double x, y, z; } Vec3;
//     Vec3 nuc_scale(Vec3 v, double k);
//     long nuc_add(long a, long b);
//     long nuc_print_dot(Vec3 a, Vec3 b);
//
// (Pre-v0.3.53 a codegen bug forced a lifted-let workaround
// for inline f64 ops on struct-field operands. v0.3.53
// extended `binop_float_type` to recognize struct field
// accesses, nested binops, and parenthesized wrappers as
// f-typed operands; the natural inline form below now
// computes correctly.)
//
// See docs/v0.3-robotics-guide.md cookbook §6 for the C-side
// caller pattern; tests/fixtures/t34_export.nr is the verify
// gate fixture (compile-only — it doesn't surface the
// codegen bug); this file shows the shipped surface in
// runnable form.

#[repr(C)]
struct Vec3 { x: f64, y: f64, z: f64 }

#[export]
fn nuc_scale(v: Vec3, k: f64) -> Vec3 {
    return Vec3 { x: v.x * k, y: v.y * k, z: v.z * k };
}

#[export]
fn nuc_add(a: i64, b: i64) -> i64 {
    return a + b;
}

// Natural inline dot product — works correctly post-v0.3.53.
#[export]
fn nuc_print_dot(a: Vec3, b: Vec3) -> i64 {
    let dp: f64 = a.x * b.x + a.y * b.y + a.z * b.z;
    print_f64(dp);
    return 0;
}

fn main() -> i64 {
    print("Vec3 ops via #[export] (also callable from C):");
    let s: Vec3 = nuc_scale(
        Vec3 { x: 1.0, y: 2.0, z: 3.0 },
        10.0);
    print("  nuc_scale((1,2,3), 10.0) = Vec3{");
    print_f64(s.x);
    print_f64(s.y);
    print_f64(s.z);
    print("  }");
    let sum: i64 = nuc_add(2, 40);
    print("  nuc_add(2, 40) =");
    print(int_to_str(sum));
    print("  nuc_print_dot((1,2,3), (4,5,6)) =");
    let _: i64 = nuc_print_dot(
        Vec3 { x: 1.0, y: 2.0, z: 3.0 },
        Vec3 { x: 4.0, y: 5.0, z: 6.0 });
    return 0;
}
