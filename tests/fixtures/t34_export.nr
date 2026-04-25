// T3.4 (v0.3.4) #[export] fixture — used by the verify gate
// to assert `nuc gen-headers` emits C forward declarations
// for Nucleor fns marked `#[export]` (callable from external
// C/C++ host code through the unmangled LLVM symbol).

#[repr(C)]
struct Vec3 {
    x: f64,
    y: f64,
    z: f64,
}

extern fn host_logger(msg_ptr: i64, msg_len: i64) -> void;

#[export]
fn nuc_add(a: i64, b: i64) -> i64 {
    return a + b;
}

#[export]
pub fn nuc_dot(a: Vec3, b: Vec3) -> f64 {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

#[export]
fn nuc_noop() {
}

fn private_helper(x: i64) -> i64 {
    return x * 2;
}

fn main() -> i64 {
    return nuc_add(1, 2);
}
