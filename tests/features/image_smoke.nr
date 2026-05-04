// v0.8.111 stdlib/rods/image.nr first test coverage.
//
// Per the zero-coverage rod survey, image.nr (RGBA image —
// construction, pixel access, PPM/BMP I/O, greyscale, resize,
// convolution) had no existing tests. Silent regressions in
// pixel storage or color-channel order would corrupt every
// downstream image pipeline.
//
// Locks textbook image invariants:
//   1. img_new + img_width + img_height: dimensions round-trip.
//   2. set_pixel + get_pixel: per-channel R/G/B/A round-trip.
//   3. Distinct pixels at distinct coordinates don't bleed
//      (no shared backing).
//   4. img_grayscale produces a same-dimension image (basic
//      smoke; perceptual luma not asserted).
//   5. img_resize produces an image with the requested
//      dimensions.
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/image.nr"

fn check_dimensions() -> i64 {
    let im: i64 = img_new(640, 480);
    if img_width(im) != 640 { img_free(im); return 1; };
    if img_height(im) != 480 { img_free(im); return 2; };
    img_free(im);
    return 0;
}

fn check_pixel_round_trip() -> i64 {
    let im: i64 = img_new(8, 8);
    img_set_pixel(im, 3, 5, 10, 20, 30, 40);
    let r: i64 = img_get_r(im, 3, 5);
    let g: i64 = img_get_g(im, 3, 5);
    let b: i64 = img_get_b(im, 3, 5);
    let a: i64 = img_get_a(im, 3, 5);
    img_free(im);
    if r != 10 { return 4; };
    if g != 20 { return 8; };
    if b != 30 { return 16; };
    if a != 40 { return 32; };
    return 0;
}

fn check_pixels_distinct() -> i64 {
    let im: i64 = img_new(8, 8);
    img_set_pixel(im, 0, 0, 255, 0, 0, 255);
    img_set_pixel(im, 7, 7, 0, 255, 0, 255);
    let r1: i64 = img_get_r(im, 0, 0);
    let g1: i64 = img_get_g(im, 0, 0);
    let r2: i64 = img_get_r(im, 7, 7);
    let g2: i64 = img_get_g(im, 7, 7);
    img_free(im);
    if r1 != 255 { return 64; };
    if g1 != 0   { return 128; };
    if r2 != 0   { return 256; };
    if g2 != 255 { return 512; };
    return 0;
}

fn check_grayscale_dimensions() -> i64 {
    let im: i64 = img_new(16, 12);
    img_set_pixel(im, 0, 0, 100, 100, 100, 255);
    let gs: i64 = img_grayscale(im);
    let w: i64 = img_width(gs);
    let h: i64 = img_height(gs);
    img_free(im);
    img_free(gs);
    if w != 16 { return 1024; };
    if h != 12 { return 2048; };
    return 0;
}

fn check_resize_dimensions() -> i64 {
    let im: i64 = img_new(100, 100);
    let small: i64 = img_resize(im, 25, 50);
    let w: i64 = img_width(small);
    let h: i64 = img_height(small);
    img_free(im);
    img_free(small);
    if w != 25 { return 4096; };
    if h != 50 { return 8192; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_dimensions();
    fails = fails + check_pixel_round_trip();
    fails = fails + check_pixels_distinct();
    fails = fails + check_grayscale_dimensions();
    fails = fails + check_resize_dimensions();
    return fails;
}
