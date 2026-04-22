// rods/color — Color space conversions and palette ops
#cfile "../runtime/color_rt.c"

extern fn nuc_color_rgb_to_hsv(r: i64, g: i64, b: i64) -> i64;
extern fn nuc_color_hsv_to_rgb(h: i64, s: i64, v: i64) -> i64;
extern fn nuc_color_rgb_to_lab(r: i64, g: i64, b: i64) -> i64;
extern fn nuc_color_lab_to_rgb(L: i64, a: i64, b: i64) -> i64;
extern fn nuc_color_delta_e(lab1: i64, lab2: i64) -> i64;
extern fn nuc_color_lerp(c1: i64, c2: i64, t: i64) -> i64;
extern fn nuc_color_palette(n: i64) -> i64;

fn color_rgb_to_hsv(r: i64, g: i64, b: i64) -> i64 { return nuc_color_rgb_to_hsv(r, g, b); }
fn color_hsv_to_rgb(h: i64, s: i64, v: i64) -> i64 { return nuc_color_hsv_to_rgb(h, s, v); }
fn color_rgb_to_lab(r: i64, g: i64, b: i64) -> i64 { return nuc_color_rgb_to_lab(r, g, b); }
fn color_lab_to_rgb(L: i64, a: i64, b: i64) -> i64 { return nuc_color_lab_to_rgb(L, a, b); }
fn color_delta_e(lab1: i64, lab2: i64) -> i64 { return nuc_color_delta_e(lab1, lab2); }
fn color_lerp(c1: i64, c2: i64, t: i64) -> i64 { return nuc_color_lerp(c1, c2, t); }
fn color_palette(n: i64) -> i64 { return nuc_color_palette(n); }
