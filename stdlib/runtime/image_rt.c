// image_rt.c — Image Reading, Writing, Basic Processing for Nucleor
// Minimal PNG read/write (uncompressed), resize, grayscale, convolution.
// For ML data pipelines and visualization.
//
// Compile: clang -c stdlib/runtime/image_rt.c -o target/image_rt.obj -O2

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _im_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _im_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } IMVec;

// ================================================================
//  Image Structure (RGBA, 8-bit per channel)
// ================================================================

typedef struct {
    int width, height;
    unsigned char *pixels;  // RGBA, width*height*4 bytes
} NImage;

long long nuc_img_new(long long width, long long height) {
    NImage *img = (NImage *)malloc(sizeof(NImage));
    img->width = (int)width; img->height = (int)height;
    img->pixels = (unsigned char *)calloc((size_t)(img->width) * img->height * 4, 1);
    return (long long)img;
}

long long nuc_img_width(long long h) { return ((NImage *)(void *)h)->width; }
long long nuc_img_height(long long h) { return ((NImage *)(void *)h)->height; }

void nuc_img_set_pixel(long long h, long long x, long long y,
                        long long r, long long g, long long b, long long a) {
    NImage *img = (NImage *)(void *)h;
    int idx = ((int)y * img->width + (int)x) * 4;
    img->pixels[idx] = (unsigned char)r;
    img->pixels[idx + 1] = (unsigned char)g;
    img->pixels[idx + 2] = (unsigned char)b;
    img->pixels[idx + 3] = (unsigned char)a;
}

long long nuc_img_get_pixel_r(long long h, long long x, long long y) {
    NImage *img = (NImage *)(void *)h;
    return img->pixels[((int)y * img->width + (int)x) * 4];
}
long long nuc_img_get_pixel_g(long long h, long long x, long long y) {
    NImage *img = (NImage *)(void *)h;
    return img->pixels[((int)y * img->width + (int)x) * 4 + 1];
}
long long nuc_img_get_pixel_b(long long h, long long x, long long y) {
    NImage *img = (NImage *)(void *)h;
    return img->pixels[((int)y * img->width + (int)x) * 4 + 2];
}
long long nuc_img_get_pixel_a(long long h, long long x, long long y) {
    NImage *img = (NImage *)(void *)h;
    return img->pixels[((int)y * img->width + (int)x) * 4 + 3];
}

// ================================================================
//  PPM Read/Write (simpler than PNG, no compression needed)
// ================================================================

void nuc_img_save_ppm(long long h, const char *path) {
    NImage *img = (NImage *)(void *)h;
    if (!img || !path) return;
    FILE *f = fopen(path, "wb");
    if (!f) return;
    fprintf(f, "P6\n%d %d\n255\n", img->width, img->height);
    for (int i = 0; i < img->width * img->height; i++) {
        fputc(img->pixels[i * 4], f);
        fputc(img->pixels[i * 4 + 1], f);
        fputc(img->pixels[i * 4 + 2], f);
    }
    fclose(f);
}

long long nuc_img_load_ppm(const char *path) {
    if (!path) return 0;
    FILE *f = fopen(path, "rb");
    if (!f) return 0;
    char magic[3];
    int w, h, maxval;
    fscanf(f, "%2s %d %d %d", magic, &w, &h, &maxval);
    fgetc(f); // skip whitespace
    if (strcmp(magic, "P6") != 0) { fclose(f); return 0; }

    NImage *img = (NImage *)malloc(sizeof(NImage));
    img->width = w; img->height = h;
    img->pixels = (unsigned char *)malloc((size_t)w * h * 4);
    for (int i = 0; i < w * h; i++) {
        img->pixels[i * 4] = (unsigned char)fgetc(f);
        img->pixels[i * 4 + 1] = (unsigned char)fgetc(f);
        img->pixels[i * 4 + 2] = (unsigned char)fgetc(f);
        img->pixels[i * 4 + 3] = 255;
    }
    fclose(f);
    return (long long)img;
}

// ================================================================
//  BMP Write (widely supported, easy to generate)
// ================================================================

void nuc_img_save_bmp(long long h, const char *path) {
    NImage *img = (NImage *)(void *)h;
    if (!img || !path) return;
    FILE *f = fopen(path, "wb");
    if (!f) return;
    int w = img->width, ht = img->height;
    int row_bytes = w * 3;
    int pad = (4 - row_bytes % 4) % 4;
    int data_size = (row_bytes + pad) * ht;
    int file_size = 54 + data_size;

    // BMP header
    unsigned char header[54] = {0};
    header[0] = 'B'; header[1] = 'M';
    memcpy(header + 2, &file_size, 4);
    int offset = 54; memcpy(header + 10, &offset, 4);
    int info_size = 40; memcpy(header + 14, &info_size, 4);
    memcpy(header + 18, &w, 4);
    memcpy(header + 22, &ht, 4);
    short planes = 1; memcpy(header + 26, &planes, 2);
    short bpp = 24; memcpy(header + 28, &bpp, 2);
    memcpy(header + 34, &data_size, 4);
    fwrite(header, 1, 54, f);

    // Pixel data (bottom-up, BGR)
    unsigned char padding[3] = {0};
    for (int y = ht - 1; y >= 0; y--) {
        for (int x = 0; x < w; x++) {
            int idx = (y * w + x) * 4;
            fputc(img->pixels[idx + 2], f); // B
            fputc(img->pixels[idx + 1], f); // G
            fputc(img->pixels[idx], f);     // R
        }
        fwrite(padding, 1, pad, f);
    }
    fclose(f);
}

// ================================================================
//  Grayscale
// ================================================================

long long nuc_img_grayscale(long long h) {
    NImage *src = (NImage *)(void *)h;
    NImage *dst = (NImage *)malloc(sizeof(NImage));
    dst->width = src->width; dst->height = src->height;
    dst->pixels = (unsigned char *)malloc((size_t)(src->width) * src->height * 4);
    for (int i = 0; i < src->width * src->height; i++) {
        unsigned char r = src->pixels[i * 4], g = src->pixels[i * 4 + 1], b = src->pixels[i * 4 + 2];
        unsigned char gray = (unsigned char)(0.299 * r + 0.587 * g + 0.114 * b);
        dst->pixels[i * 4] = gray;
        dst->pixels[i * 4 + 1] = gray;
        dst->pixels[i * 4 + 2] = gray;
        dst->pixels[i * 4 + 3] = src->pixels[i * 4 + 3];
    }
    return (long long)dst;
}

// ================================================================
//  Resize (bilinear)
// ================================================================

long long nuc_img_resize(long long h, long long new_w, long long new_h) {
    NImage *src = (NImage *)(void *)h;
    int nw = (int)new_w, nh = (int)new_h;
    NImage *dst = (NImage *)malloc(sizeof(NImage));
    dst->width = nw; dst->height = nh;
    dst->pixels = (unsigned char *)malloc((size_t)nw * nh * 4);

    double sx = (double)src->width / nw, sy = (double)src->height / nh;
    for (int y = 0; y < nh; y++) {
        for (int x = 0; x < nw; x++) {
            double fx = x * sx, fy = y * sy;
            int x0 = (int)fx, y0 = (int)fy;
            int x1 = x0 + 1, y1 = y0 + 1;
            if (x1 >= src->width) x1 = src->width - 1;
            if (y1 >= src->height) y1 = src->height - 1;
            double dx = fx - x0, dy = fy - y0;

            for (int c = 0; c < 4; c++) {
                double v00 = src->pixels[(y0 * src->width + x0) * 4 + c];
                double v10 = src->pixels[(y0 * src->width + x1) * 4 + c];
                double v01 = src->pixels[(y1 * src->width + x0) * 4 + c];
                double v11 = src->pixels[(y1 * src->width + x1) * 4 + c];
                double v = v00 * (1-dx)*(1-dy) + v10 * dx*(1-dy) + v01 * (1-dx)*dy + v11 * dx*dy;
                dst->pixels[(y * nw + x) * 4 + c] = (unsigned char)(v + 0.5);
            }
        }
    }
    return (long long)dst;
}

// ================================================================
//  Convolution (3x3 kernel on grayscale channel)
// ================================================================

long long nuc_img_convolve(long long h, long long kernel_h) {
    NImage *src = (NImage *)(void *)h;
    IMVec *kern = (IMVec *)(void *)kernel_h; // 9 f64 values
    NImage *dst = (NImage *)malloc(sizeof(NImage));
    dst->width = src->width; dst->height = src->height;
    dst->pixels = (unsigned char *)calloc((size_t)(src->width) * src->height * 4, 1);

    for (int y = 1; y < src->height - 1; y++) {
        for (int x = 1; x < src->width - 1; x++) {
            for (int c = 0; c < 3; c++) {
                double sum = 0;
                for (int ky = -1; ky <= 1; ky++)
                    for (int kx = -1; kx <= 1; kx++) {
                        double k = _im_i2f(kern->data[(ky + 1) * 3 + kx + 1]);
                        sum += k * src->pixels[((y + ky) * src->width + x + kx) * 4 + c];
                    }
                int v = (int)(sum + 0.5);
                if (v < 0) v = 0; if (v > 255) v = 255;
                dst->pixels[(y * src->width + x) * 4 + c] = (unsigned char)v;
            }
            dst->pixels[(y * src->width + x) * 4 + 3] = src->pixels[(y * src->width + x) * 4 + 3];
        }
    }
    return (long long)dst;
}

// ================================================================
//  To/From ML tensor (flat f64 array, normalized to [0,1])
// ================================================================

long long nuc_img_to_tensor(long long h) {
    NImage *img = (NImage *)(void *)h;
    int n = img->width * img->height * 3;
    IMVec *v = (IMVec *)malloc(sizeof(IMVec));
    v->len = n; v->cap = n;
    v->data = (long long *)malloc(n * sizeof(long long));
    for (int i = 0; i < img->width * img->height; i++) {
        v->data[i * 3] = _im_f2i(img->pixels[i * 4] / 255.0);
        v->data[i * 3 + 1] = _im_f2i(img->pixels[i * 4 + 1] / 255.0);
        v->data[i * 3 + 2] = _im_f2i(img->pixels[i * 4 + 2] / 255.0);
    }
    return (long long)v;
}

void nuc_img_free(long long h) {
    NImage *img = (NImage *)(void *)h;
    if (img) { free(img->pixels); free(img); }
}
