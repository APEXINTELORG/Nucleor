// rods/f64_buffer -- typed scratch buffers for raw double[] rod APIs.
//
// Robotics, vision, estimation, and trajectory rods often take
// caller-owned `double[n]` buffers for zero-copy C interop. This rod
// supplies the minimal public Nucleor surface for building those
// buffers, passing their raw pointer to other rods, and reading the
// mutated values back.

#cfile "../runtime/f64_buffer_rt.c"

extern fn nuc_f64_buf_new(len: i64) -> i64;
extern fn nuc_f64_buf_len(h: i64) -> i64;
extern fn nuc_f64_buf_ptr(h: i64) -> i64;
extern fn nuc_f64_buf_set(h: i64, idx: i64, val_bits: i64) -> i64;
extern fn nuc_f64_buf_get(h: i64, idx: i64) -> i64;
extern fn nuc_f64_buf_zero(h: i64);
extern fn nuc_f64_buf_free(h: i64);

fn f64_buf_new(len: i64) -> i64 { return nuc_f64_buf_new(len); }
fn f64_buf_len(h: i64) -> i64 { return nuc_f64_buf_len(h); }
fn f64_buf_ptr(h: i64) -> i64 { return nuc_f64_buf_ptr(h); }
fn f64_buf_free(h: i64) { nuc_f64_buf_free(h); }
fn f64_buf_zero(h: i64) { nuc_f64_buf_zero(h); }

fn f64_buf_set_bits(h: i64, idx: i64, val_bits: i64) -> i64 {
    return nuc_f64_buf_set(h, idx, val_bits);
}

fn f64_buf_get_bits(h: i64, idx: i64) -> i64 {
    return nuc_f64_buf_get(h, idx);
}

fn f64_buf_set(h: i64, idx: i64, val: f64) -> i64 {
    return nuc_f64_buf_set(h, idx, f64_to_bits(val));
}

fn f64_buf_get(h: i64, idx: i64) -> f64 {
    return f64_from_bits(nuc_f64_buf_get(h, idx));
}
