// color_rt.c — Color Space Conversion for Nucleor
// RGB↔HSV, RGB↔Lab, perceptual distance, interpolation, palette generation.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/color_rt.c -o target/color_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _co_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _co_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } COVec;

static COVec *covec_new(int n) {
    COVec *v = (COVec *)malloc(sizeof(COVec));
    v->len = n; v->cap = n;
    v->data = (long long *)calloc(n, sizeof(long long));
    return v;
}

// ================================================================
//  RGB → HSV (r,g,b in [0,1])
// ================================================================

long long nuc_color_rgb_to_hsv(long long r_b, long long g_b, long long b_b) {
    double r = _co_i2f(r_b), g = _co_i2f(g_b), b = _co_i2f(b_b);
    double cmax = r > g ? (r > b ? r : b) : (g > b ? g : b);
    double cmin = r < g ? (r < b ? r : b) : (g < b ? g : b);
    double delta = cmax - cmin;

    double h = 0, s = 0, v = cmax;
    if (delta > 1e-10) {
        s = delta / cmax;
        if (cmax == r) h = 60 * fmod((g - b) / delta, 6);
        else if (cmax == g) h = 60 * ((b - r) / delta + 2);
        else h = 60 * ((r - g) / delta + 4);
        if (h < 0) h += 360;
    }

    COVec *result = covec_new(3);
    result->data[0] = _co_f2i(h);
    result->data[1] = _co_f2i(s);
    result->data[2] = _co_f2i(v);
    return (long long)result;
}

// ================================================================
//  HSV → RGB
// ================================================================

long long nuc_color_hsv_to_rgb(long long h_b, long long s_b, long long v_b) {
    double h = _co_i2f(h_b), s = _co_i2f(s_b), v = _co_i2f(v_b);
    double c = v * s, x = c * (1 - fabs(fmod(h / 60, 2) - 1)), m = v - c;
    double r = 0, g = 0, b = 0;

    if (h < 60)       { r = c; g = x; }
    else if (h < 120) { r = x; g = c; }
    else if (h < 180) { g = c; b = x; }
    else if (h < 240) { g = x; b = c; }
    else if (h < 300) { r = x; b = c; }
    else              { r = c; b = x; }

    COVec *result = covec_new(3);
    result->data[0] = _co_f2i(r + m);
    result->data[1] = _co_f2i(g + m);
    result->data[2] = _co_f2i(b + m);
    return (long long)result;
}

// ================================================================
//  RGB → CIE Lab (via XYZ, D65 illuminant)
// ================================================================

static double srgb_to_linear(double c) {
    return (c <= 0.04045) ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4);
}

static double lab_f(double t) {
    return (t > 0.008856) ? cbrt(t) : (7.787 * t + 16.0 / 116.0);
}

long long nuc_color_rgb_to_lab(long long r_b, long long g_b, long long b_b) {
    double rl = srgb_to_linear(_co_i2f(r_b));
    double gl = srgb_to_linear(_co_i2f(g_b));
    double bl = srgb_to_linear(_co_i2f(b_b));

    // D65 reference
    double x = (0.4124564 * rl + 0.3575761 * gl + 0.1804375 * bl) / 0.95047;
    double y = (0.2126729 * rl + 0.7151522 * gl + 0.0721750 * bl) / 1.00000;
    double z = (0.0193339 * rl + 0.1191920 * gl + 0.9503041 * bl) / 1.08883;

    double L = 116 * lab_f(y) - 16;
    double a = 500 * (lab_f(x) - lab_f(y));
    double bb = 200 * (lab_f(y) - lab_f(z));

    COVec *result = covec_new(3);
    result->data[0] = _co_f2i(L);
    result->data[1] = _co_f2i(a);
    result->data[2] = _co_f2i(bb);
    return (long long)result;
}

// ================================================================
//  Lab → RGB
// ================================================================

static double linear_to_srgb(double c) {
    return (c <= 0.0031308) ? 12.92 * c : 1.055 * pow(c, 1.0 / 2.4) - 0.055;
}

static double lab_f_inv(double t) {
    return (t > 0.206897) ? t * t * t : (t - 16.0 / 116.0) / 7.787;
}

long long nuc_color_lab_to_rgb(long long L_b, long long a_b, long long bb_b) {
    double L = _co_i2f(L_b), a = _co_i2f(a_b), b = _co_i2f(bb_b);
    double fy = (L + 16) / 116;
    double fx = a / 500 + fy;
    double fz = fy - b / 200;

    double x = 0.95047 * lab_f_inv(fx);
    double y = 1.00000 * lab_f_inv(fy);
    double z = 1.08883 * lab_f_inv(fz);

    double rl = 3.2404542 * x - 1.5371385 * y - 0.4985314 * z;
    double gl = -0.9692660 * x + 1.8760108 * y + 0.0415560 * z;
    double bl = 0.0556434 * x - 0.2040259 * y + 1.0572252 * z;

    double r = linear_to_srgb(rl), g = linear_to_srgb(gl), bv = linear_to_srgb(bl);
    if (r < 0) r = 0; if (r > 1) r = 1;
    if (g < 0) g = 0; if (g > 1) g = 1;
    if (bv < 0) bv = 0; if (bv > 1) bv = 1;

    COVec *result = covec_new(3);
    result->data[0] = _co_f2i(r);
    result->data[1] = _co_f2i(g);
    result->data[2] = _co_f2i(bv);
    return (long long)result;
}

// ================================================================
//  Delta-E (CIE76 perceptual color distance)
// ================================================================

long long nuc_color_delta_e(long long lab1_h, long long lab2_h) {
    COVec *a = (COVec *)(void *)lab1_h, *b = (COVec *)(void *)lab2_h;
    double dL = _co_i2f(a->data[0]) - _co_i2f(b->data[0]);
    double da = _co_i2f(a->data[1]) - _co_i2f(b->data[1]);
    double db = _co_i2f(a->data[2]) - _co_i2f(b->data[2]);
    return _co_f2i(sqrt(dL * dL + da * da + db * db));
}

// ================================================================
//  Color Interpolation (linear in Lab space)
// ================================================================

long long nuc_color_lerp(long long c1_h, long long c2_h, long long t_bits) {
    COVec *c1 = (COVec *)(void *)c1_h, *c2 = (COVec *)(void *)c2_h;
    double t = _co_i2f(t_bits);
    COVec *result = covec_new(3);
    for (int i = 0; i < 3; i++) {
        double a = _co_i2f(c1->data[i]), b = _co_i2f(c2->data[i]);
        result->data[i] = _co_f2i(a + t * (b - a));
    }
    return (long long)result;
}

// ================================================================
//  Generate N perceptually distinct colors (golden-angle hue spacing)
// ================================================================

long long nuc_color_palette(long long n) {
    int N = (int)n;
    COVec *result = covec_new(N * 3);
    double golden = 137.508; // golden angle in degrees
    for (int i = 0; i < N; i++) {
        double h = fmod(i * golden, 360.0);
        double s = 0.65 + 0.2 * (i % 3) / 2.0;
        double v = 0.85 + 0.1 * ((i / 3) % 2);
        long long rgb = nuc_color_hsv_to_rgb(_co_f2i(h), _co_f2i(s), _co_f2i(v));
        COVec *c = (COVec *)(void *)rgb;
        result->data[i * 3] = c->data[0];
        result->data[i * 3 + 1] = c->data[1];
        result->data[i * 3 + 2] = c->data[2];
    }
    return (long long)result;
}
