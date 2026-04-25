// T3.44 (v0.3.69) — regression test for trait method calls
// returning structs + immediate field access (`v.rotated().x`).
//
// Pre-v0.3.69: `v.rotated().x` failed compilation with
// `ERROR: cannot resolve field access type for .x`.
// expr_struct_type's kind 9 (field access) recursed on the
// operand `v.rotated()` (kind 8 method call), but kind 8
// wasn't in expr_struct_type's enumeration. v0.3.69 mirrors
// v0.3.60's binop_float_type kind 8 fix into expr_struct_type:
// resolve receiver type, construct mangled name, look up
// __fnret_<MANGLED>.
//
// Production-relevant: builder/transform pipelines.
//   pose.rotate(q).translate(t).build().x
//   sensor.calibrate().median().value
//
// Verify gate (T3.44) asserts trait-method-result-field-access
// compiles AND produces correct values for var, fn-call, and
// inline-binop receivers.

trait Builder { fn rotated(self) -> V3; }

#[repr(C)]
struct V3 { x: f64, y: f64, z: f64 }

impl Builder for V3 {
    fn rotated(self) -> V3 {
        // Cyclic permutation: x→y→z→x.
        return V3 { x: self.y, y: self.z, z: self.x };
    }
}

fn make() -> V3 { return V3 { x: 1.0, y: 2.0, z: 3.0 }; }

fn main() -> i32 {
    // Trait method on var receiver, immediate field access.
    let v: V3 = make();
    let r1: f64 = v.rotated().x;        // 2.0 (rotated y becomes x)
    print_f64(r1);

    // Trait method on fn-call receiver, immediate field access.
    let r2: f64 = make().rotated().x;   // 2.0
    print_f64(r2);

    // Inline binop on chained method-field results.
    let r3: f64 = make().rotated().x + make().rotated().y;
    print_f64(r3);                       // 5.0 (2 + 3)

    return 0;
}
