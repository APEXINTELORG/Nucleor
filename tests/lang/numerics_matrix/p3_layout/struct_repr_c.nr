// p3_layout/struct_repr_c.nr — Phase 3: #[repr(C)] struct layout

#[repr(C)]
struct Point {
    x: i32,
    y: i32,
}

fn main() -> i32 {
    // sizeof(Point) should be 8 (two i32 fields, natural align).
    // For now we can only check field round-trip works.
    let p = Point { x: 100, y: 200 };
    if p.x != 100 || p.y != 200 {
        print("FAIL: repr(C) struct field round-trip\n");
        return 1;
    };
    print("OK struct_repr_c\n");
    return 0;
}
