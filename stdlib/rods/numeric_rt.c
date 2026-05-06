// rods/numeric runtime - IEEE-754 rounding and fused arithmetic helpers.

#include <fenv.h>
#include <math.h>
#include <stdint.h>
#include <string.h>

#pragma STDC FENV_ACCESS ON

static double nuc_num_i2f64(long long x) {
    double d;
    memcpy(&d, &x, sizeof(double));
    return d;
}

static long long nuc_num_f642i(double d) {
    long long x;
    memcpy(&x, &d, sizeof(long long));
    return x;
}

static float nuc_num_i2f32(long long x) {
    uint32_t bits = (uint32_t)x;
    float f;
    memcpy(&f, &bits, sizeof(float));
    return f;
}

static long long nuc_num_f322i(float f) {
    uint32_t bits;
    memcpy(&bits, &f, sizeof(uint32_t));
    return (long long)bits;
}

static long long nuc_num_mode_from_fe(int mode) {
    if (mode == FE_TONEAREST) return 0;
    if (mode == FE_DOWNWARD) return 1;
    if (mode == FE_UPWARD) return 2;
    if (mode == FE_TOWARDZERO) return 3;
    return -1;
}

static int nuc_num_mode_to_fe(long long mode) {
    if (mode == 0) return FE_TONEAREST;
    if (mode == 1) return FE_DOWNWARD;
    if (mode == 2) return FE_UPWARD;
    if (mode == 3) return FE_TOWARDZERO;
    return -1;
}

long long nuc_numeric_rounding_nearest(void) { return 0; }
long long nuc_numeric_rounding_downward(void) { return 1; }
long long nuc_numeric_rounding_upward(void) { return 2; }
long long nuc_numeric_rounding_toward_zero(void) { return 3; }

long long nuc_numeric_get_rounding_mode(void) {
    return nuc_num_mode_from_fe(fegetround());
}

long long nuc_numeric_set_rounding_mode(long long mode) {
    int fe_mode = nuc_num_mode_to_fe(mode);
    if (fe_mode < 0) return -1;
    long long prev = nuc_numeric_get_rounding_mode();
    if (fesetround(fe_mode) != 0) return -1;
    return prev;
}

long long nuc_numeric_f64_next_up(long long x) {
    return nuc_num_f642i(nextafter(nuc_num_i2f64(x), INFINITY));
}

long long nuc_numeric_f64_next_down(long long x) {
    return nuc_num_f642i(nextafter(nuc_num_i2f64(x), -INFINITY));
}

long long nuc_numeric_f64_mul_add(long long a, long long b, long long c) {
    return nuc_num_f642i(fma(nuc_num_i2f64(a), nuc_num_i2f64(b), nuc_num_i2f64(c)));
}

long long nuc_numeric_f32_mul_add(long long a, long long b, long long c) {
    return nuc_num_f322i(fmaf(nuc_num_i2f32(a), nuc_num_i2f32(b), nuc_num_i2f32(c)));
}
