// p3_layout/sizeof_struct_basic.nr — Phase 3b:
// sizeof_struct(<Name>) returns compile-time byte size of a struct.
// Current default Nucleor repr stores one i64 slot per field,
// so 2-field struct = 16 bytes, 3-field = 24 bytes.
// Phase 3b.2 (follow-up) wires repr(C)/repr(packed) attribute
// propagation for tighter packing.

struct Point {
    x: i32,
    y: i32,
}

struct Three {
    a: i32,
    b: i32,
    c: i32,
}

struct Single {
    x: i64,
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    if sizeof_struct(Point)  != 16 { fail = fail + 1; print("FAIL: sizeof_struct(Point)\n"); };
    if sizeof_struct(Three)  != 24 { fail = fail + 1; print("FAIL: sizeof_struct(Three)\n"); };
    if sizeof_struct(Single) != 8  { fail = fail + 1; print("FAIL: sizeof_struct(Single)\n"); };
    if fail == 0 { print("OK sizeof_struct_basic\n"); return 0; };
    return 1;
}
