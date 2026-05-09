/*
 * Lane 3 (C-008): C reference for lane3_diff_int_widths.nr.
 * Output must be byte-identical to the Nucleor build's stdout.
 * Run via:  clang -O0 lane3_diff_int_widths.c -o ref && ./ref
 */
#include <stdint.h>
#include <stdio.h>

static void kv(const char *k, int64_t v) { printf("%s=%lld\n", k, (long long)v); }

int main(void) {
    uint8_t  u8a = 200, u8b = 100;
    uint8_t  u8s = (uint8_t)(u8a + u8b);
    kv("u8_wrap", (int64_t)u8s);

    uint32_t u32a = 4294967290u, u32b = 10u;
    uint32_t u32s = u32a + u32b;
    kv("u32_wrap", (int64_t)u32s);

    int32_t  i32a = -1;
    int64_t  widened = (int64_t)i32a;
    kv("i32_sx", widened);

    uint32_t u32c = 4294967295u;
    int64_t  widened_u = (int64_t)(uint64_t)u32c;
    kv("u32_zx", widened_u);

    int64_t  i64a = 257;
    int8_t   truncated = (int8_t)i64a;
    kv("i8_trunc", (int64_t)truncated);

    kv("sdiv_neg", (int64_t)(-7) / 2);
    kv("smod_neg", (int64_t)(-7) % 2);
    return 0;
}
