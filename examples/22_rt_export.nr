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
// **v1 codegen note**: f64 multiplication of two struct-field
// accesses INLINE (e.g. `a.x * b.x` directly inside a
// larger expression) miscomputes to 0 when the struct args
// are passed by value. Workaround: lift each field to an
// intermediate `let`-binding before the multiply (e.g.
// `let ax: f64 = a.x; let bx: f64 = b.x; let prod: f64 =
// ax * bx;`). The bug is in struct-field-load + fmul
// scheduling; receive (Vec3, Vec3) works, multiply via
// intermediate vars works, only the inline form misfires.
// The v0.4 AST-based codegen owns the fix.
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

// Dot product with the intermediate-let workaround for the
// v1 codegen bug noted above. Each field is lifted to its
// own f64 binding AND each multiplication is its own let
// before being summed; without that splitting the inline
// `ax * bx + ay * by + az * bz` form mis-schedules the
// fmuls and the sum comes out wrong.
#[export]
fn nuc_print_dot(a: Vec3, b: Vec3) -> i64 {
    let ax: f64 = a.x; let ay: f64 = a.y; let az: f64 = a.z;
    let bx: f64 = b.x; let by: f64 = b.y; let bz: f64 = b.z;
    let p1: f64 = ax * bx;
    let p2: f64 = ay * by;
    let p3: f64 = az * bz;
    let dp: f64 = p1 + p2 + p3;
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
