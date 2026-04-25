// T1.6 (v0.2.345) C ABI struct-by-value fixture.
// Verifies `nuc gen-headers` produces typedef structs for
// #[repr(C)] decls and accepts struct names in extern fn signatures.
// Non-repr(C) structs (PrivateInternal here) must NOT appear in the
// generated header.

#[repr(C)]
struct Point2D {
    x: f64,
    y: f64,
}

#[repr(C)]
pub struct Color {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
}

struct PrivateInternal {
    secret: i64,
}

extern fn distance(a: Point2D, b: Point2D) -> f64;
extern fn fill_pixel(c: Color, count: i64);
