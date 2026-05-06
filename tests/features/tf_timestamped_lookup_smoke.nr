// helper1 ROBO-5 -- timestamped TF interpolation smoke.
//
// Locks the additive latest-two-samples timestamp path:
// add_frame_at -> set_pose_at -> lookup_at interpolates translation.

import "stdlib/rods/tf.nr"
import "stdlib/rods/f64_buffer.nr"

fn close(a: f64, b: f64, eps: f64) -> i64 {
    let d: f64 = a - b;
    let ad: f64 = if d < 0.0 { 0.0 - d } else { d };
    if ad < eps { return 1; };
    return 0;
}

fn set_t(h: i64, x: f64, y: f64, z: f64) {
    f64_buf_set(h, 0, x);
    f64_buf_set(h, 1, y);
    f64_buf_set(h, 2, z);
}

fn set_q_identity(h: i64) {
    f64_buf_set(h, 0, 1.0);
    f64_buf_set(h, 1, 0.0);
    f64_buf_set(h, 2, 0.0);
    f64_buf_set(h, 3, 0.0);
}

fn main() -> i64 {
    let tf: i64 = tf_new(4);
    let t: i64 = f64_buf_new(3);
    let q: i64 = f64_buf_new(4);
    let out_t: i64 = f64_buf_new(3);
    let out_q: i64 = f64_buf_new(4);
    if tf == 0 || t == 0 || q == 0 || out_t == 0 || out_q == 0 { return 1; };

    set_t(t, 0.0, 0.0, 0.0);
    set_q_identity(q);
    if tf_add_frame_at(tf, 0, 0 - 1, f64_to_bits(0.0), f64_buf_ptr(t), f64_buf_ptr(q)) != 1 {
        return 2;
    };
    if tf_add_frame_at(tf, 1, 0, f64_to_bits(0.0), f64_buf_ptr(t), f64_buf_ptr(q)) != 1 {
        return 4;
    };

    set_t(t, 10.0, 0.0, 0.0);
    if tf_set_pose_at(tf, 1, f64_to_bits(10.0), f64_buf_ptr(t), f64_buf_ptr(q)) != 1 {
        return 8;
    };

    if tf_lookup_at(tf, 0, 1, f64_to_bits(5.0), f64_buf_ptr(out_t), f64_buf_ptr(out_q)) != 1 {
        return 16;
    };
    if close(f64_buf_get(out_t, 0), 5.0, 0.000001) != 1 { return 32; };
    if close(f64_buf_get(out_t, 1), 0.0, 0.000001) != 1 { return 64; };
    if close(f64_buf_get(out_q, 0), 1.0, 0.000001) != 1 { return 128; };

    if tf_lookup_at(tf, 0, 1, f64_to_bits(11.0), f64_buf_ptr(out_t), f64_buf_ptr(out_q)) != 0 {
        return 256;
    };

    if tf_lookup(tf, 0, 1, f64_buf_ptr(out_t), f64_buf_ptr(out_q)) != 1 {
        return 512;
    };
    if close(f64_buf_get(out_t, 0), 10.0, 0.000001) != 1 { return 1024; };

    f64_buf_free(t);
    f64_buf_free(q);
    f64_buf_free(out_t);
    f64_buf_free(out_q);
    tf_free(tf);
    return 0;
}
