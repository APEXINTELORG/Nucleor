// v0.8 helper1 -- f64_buffer first coverage.
//
// Locks the typed scratch-buffer surface needed by raw double[] rods:
// construction, length, raw pointer exposure, set/get round-trip, zero,
// and free. Expected: rc=0.

import "stdlib/rods/f64_buffer.nr"

fn close(a: f64, b: f64, eps: f64) -> i64 {
    let d: f64 = a - b;
    let ad: f64 = if d < 0.0 { 0.0 - d } else { d };
    if ad < eps { return 1; };
    return 0;
}

fn main() -> i64 {
    let h: i64 = f64_buf_new(3);
    if h == 0 { return 1; };
    if f64_buf_len(h) != 3 { f64_buf_free(h); return 2; };
    if f64_buf_ptr(h) == 0 { f64_buf_free(h); return 4; };
    if f64_buf_set(h, 0, 1.25) != 1 { f64_buf_free(h); return 8; };
    if f64_buf_set(h, 1, 0.0 - 2.5) != 1 { f64_buf_free(h); return 16; };
    if close(f64_buf_get(h, 0), 1.25, 1e-12) != 1 { f64_buf_free(h); return 32; };
    if close(f64_buf_get(h, 1), 0.0 - 2.5, 1e-12) != 1 { f64_buf_free(h); return 64; };
    f64_buf_zero(h);
    if close(f64_buf_get(h, 0), 0.0, 1e-12) != 1 { f64_buf_free(h); return 128; };
    if close(f64_buf_get(h, 1), 0.0, 1e-12) != 1 { f64_buf_free(h); return 256; };
    if f64_buf_set(h, 3, 1.0) != 0 { f64_buf_free(h); return 512; };
    f64_buf_free(h);
    return 0;
}
