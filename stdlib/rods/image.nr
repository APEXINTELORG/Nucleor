// =====================================================
// rods/image — RGBA image processing
// =====================================================
// Import: import "stdlib/rods/image.nr"
// Provides: image construction, per-pixel access, PPM/BMP I/O,
//   greyscale conversion, resize, convolution, tensor conversion.
// =====================================================

#cfile "../runtime/image_rt.c"

extern fn nuc_img_new(w: i64, h: i64) -> i64;
extern fn nuc_img_width(h: i64) -> i64;
extern fn nuc_img_height(h: i64) -> i64;
extern fn nuc_img_set_pixel(h: i64, x: i64, y: i64, r: i64, g: i64, b: i64, a: i64);
extern fn nuc_img_get_pixel_r(h: i64, x: i64, y: i64) -> i64;
extern fn nuc_img_get_pixel_g(h: i64, x: i64, y: i64) -> i64;
extern fn nuc_img_get_pixel_b(h: i64, x: i64, y: i64) -> i64;
extern fn nuc_img_get_pixel_a(h: i64, x: i64, y: i64) -> i64;
extern fn nuc_img_save_ppm(h: i64, path: str);
extern fn nuc_img_load_ppm(path: str) -> i64;
extern fn nuc_img_save_bmp(h: i64, path: str);
extern fn nuc_img_grayscale(h: i64) -> i64;
extern fn nuc_img_resize(h: i64, w: i64, hh: i64) -> i64;
extern fn nuc_img_convolve(h: i64, kernel: i64) -> i64;
extern fn nuc_img_to_tensor(h: i64) -> i64;
extern fn nuc_img_free(h: i64);

fn img_new(w: i64, h: i64) -> i64 { return nuc_img_new(w, h); }
fn img_width(h: i64) -> i64 { return nuc_img_width(h); }
fn img_height(h: i64) -> i64 { return nuc_img_height(h); }
fn img_set_pixel(h: i64, x: i64, y: i64, r: i64, g: i64, b: i64, a: i64) {
    nuc_img_set_pixel(h, x, y, r, g, b, a);
}
fn img_get_r(h: i64, x: i64, y: i64) -> i64 { return nuc_img_get_pixel_r(h, x, y); }
fn img_get_g(h: i64, x: i64, y: i64) -> i64 { return nuc_img_get_pixel_g(h, x, y); }
fn img_get_b(h: i64, x: i64, y: i64) -> i64 { return nuc_img_get_pixel_b(h, x, y); }
fn img_get_a(h: i64, x: i64, y: i64) -> i64 { return nuc_img_get_pixel_a(h, x, y); }
fn img_save_ppm(h: i64, path: str) { nuc_img_save_ppm(h, path); }
fn img_load_ppm(path: str) -> i64 { return nuc_img_load_ppm(path); }
fn img_save_bmp(h: i64, path: str) { nuc_img_save_bmp(h, path); }
fn img_grayscale(h: i64) -> i64 { return nuc_img_grayscale(h); }
fn img_resize(h: i64, w: i64, hh: i64) -> i64 { return nuc_img_resize(h, w, hh); }
fn img_convolve(h: i64, kernel: i64) -> i64 { return nuc_img_convolve(h, kernel); }
fn img_to_tensor(h: i64) -> i64 { return nuc_img_to_tensor(h); }
fn img_free(h: i64) { nuc_img_free(h); }
