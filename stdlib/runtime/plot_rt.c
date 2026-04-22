// plot_rt.c — SVG Plot Generation for Nucleor
// Line charts, scatter plots, bar charts, heatmaps. No GUI dependency.
// Output: self-contained SVG files.
//
// Compile: clang -c stdlib/runtime/plot_rt.c -o target/plot_rt.obj -O2

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _pl_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _pl_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } PLVec;

// ================================================================
//  Plot State
// ================================================================

#define PLOT_LINE    0
#define PLOT_SCATTER 1
#define PLOT_BAR     2
#define PLOT_HEATMAP 3

typedef struct {
    int type;
    double *xs, *ys;
    int n;
    char color[32];
    char label[64];
    double size;
    // Heatmap
    double *grid;
    int grid_nx, grid_ny;
} PlotSeries;

#define MAX_SERIES 32

typedef struct {
    int width, height;
    int margin;
    char title[128];
    char xlabel[64], ylabel[64];
    double xlim[2], ylim[2];
    int xlim_set, ylim_set;
    PlotSeries series[MAX_SERIES];
    int n_series;
    int show_legend;
} Plot;

long long nuc_plot_new(long long width, long long height) {
    Plot *p = (Plot *)calloc(1, sizeof(Plot));
    p->width = (int)width; p->height = (int)height;
    p->margin = 60;
    return (long long)p;
}

// ================================================================
//  Add Series
// ================================================================

long long nuc_plot_line(long long h, long long xs_h, long long ys_h,
                         const char *color, const char *label) {
    Plot *p = (Plot *)(void *)h;
    PLVec *xs = (PLVec *)(void *)xs_h, *ys = (PLVec *)(void *)ys_h;
    if (p->n_series >= MAX_SERIES) return 0;
    PlotSeries *s = &p->series[p->n_series++];
    s->type = PLOT_LINE;
    s->n = xs->len < ys->len ? xs->len : ys->len;
    s->xs = (double *)malloc(s->n * sizeof(double));
    s->ys = (double *)malloc(s->n * sizeof(double));
    for (int i = 0; i < s->n; i++) { s->xs[i] = _pl_i2f(xs->data[i]); s->ys[i] = _pl_i2f(ys->data[i]); }
    strncpy(s->color, color ? color : "#1f77b4", 31);
    strncpy(s->label, label ? label : "", 63);
    return (long long)p->n_series;
}

long long nuc_plot_scatter(long long h, long long xs_h, long long ys_h,
                            const char *color, long long size_bits) {
    Plot *p = (Plot *)(void *)h;
    PLVec *xs = (PLVec *)(void *)xs_h, *ys = (PLVec *)(void *)ys_h;
    if (p->n_series >= MAX_SERIES) return 0;
    PlotSeries *s = &p->series[p->n_series++];
    s->type = PLOT_SCATTER;
    s->n = xs->len < ys->len ? xs->len : ys->len;
    s->xs = (double *)malloc(s->n * sizeof(double));
    s->ys = (double *)malloc(s->n * sizeof(double));
    for (int i = 0; i < s->n; i++) { s->xs[i] = _pl_i2f(xs->data[i]); s->ys[i] = _pl_i2f(ys->data[i]); }
    strncpy(s->color, color ? color : "#ff7f0e", 31);
    s->size = _pl_i2f(size_bits);
    if (s->size <= 0) s->size = 4;
    return (long long)p->n_series;
}

long long nuc_plot_heatmap(long long h, long long grid_h, long long Nx, long long Ny) {
    Plot *p = (Plot *)(void *)h;
    PLVec *grid = (PLVec *)(void *)grid_h;
    if (p->n_series >= MAX_SERIES) return 0;
    PlotSeries *s = &p->series[p->n_series++];
    s->type = PLOT_HEATMAP;
    s->grid_nx = (int)Nx; s->grid_ny = (int)Ny;
    int n = s->grid_nx * s->grid_ny;
    s->grid = (double *)malloc(n * sizeof(double));
    for (int i = 0; i < n && i < grid->len; i++) s->grid[i] = _pl_i2f(grid->data[i]);
    return (long long)p->n_series;
}

// ================================================================
//  Configuration
// ================================================================

void nuc_plot_set_title(long long h, const char *s) {
    Plot *p = (Plot *)(void *)h; if (s) strncpy(p->title, s, 127);
}
void nuc_plot_set_xlabel(long long h, const char *s) {
    Plot *p = (Plot *)(void *)h; if (s) strncpy(p->xlabel, s, 63);
}
void nuc_plot_set_ylabel(long long h, const char *s) {
    Plot *p = (Plot *)(void *)h; if (s) strncpy(p->ylabel, s, 63);
}
void nuc_plot_set_xlim(long long h, long long lo, long long hi) {
    Plot *p = (Plot *)(void *)h; p->xlim[0] = _pl_i2f(lo); p->xlim[1] = _pl_i2f(hi); p->xlim_set = 1;
}
void nuc_plot_set_ylim(long long h, long long lo, long long hi) {
    Plot *p = (Plot *)(void *)h; p->ylim[0] = _pl_i2f(lo); p->ylim[1] = _pl_i2f(hi); p->ylim_set = 1;
}
void nuc_plot_legend(long long h) { ((Plot *)(void *)h)->show_legend = 1; }

// ================================================================
//  SVG Output
// ================================================================

void nuc_plot_save_svg(long long h, const char *path) {
    Plot *p = (Plot *)(void *)h;
    if (!p || !path) return;
    FILE *f = fopen(path, "w");
    if (!f) return;

    int w = p->width, ht = p->height, m = p->margin;
    int pw = w - 2 * m, ph = ht - 2 * m;

    // Compute data bounds
    double xmin = 1e30, xmax = -1e30, ymin = 1e30, ymax = -1e30;
    for (int si = 0; si < p->n_series; si++) {
        PlotSeries *s = &p->series[si];
        if (s->type == PLOT_HEATMAP) continue;
        for (int i = 0; i < s->n; i++) {
            if (s->xs[i] < xmin) xmin = s->xs[i]; if (s->xs[i] > xmax) xmax = s->xs[i];
            if (s->ys[i] < ymin) ymin = s->ys[i]; if (s->ys[i] > ymax) ymax = s->ys[i];
        }
    }
    if (p->xlim_set) { xmin = p->xlim[0]; xmax = p->xlim[1]; }
    if (p->ylim_set) { ymin = p->ylim[0]; ymax = p->ylim[1]; }
    double xr = (xmax - xmin > 1e-15) ? xmax - xmin : 1;
    double yr = (ymax - ymin > 1e-15) ? ymax - ymin : 1;

    #define SX(x) (m + (int)(((x) - xmin) / xr * pw))
    #define SY(y) (m + ph - (int)(((y) - ymin) / yr * ph))

    fprintf(f, "<svg xmlns='http://www.w3.org/2000/svg' width='%d' height='%d' "
               "style='background:white'>\n", w, ht);

    // Axes
    fprintf(f, "<line x1='%d' y1='%d' x2='%d' y2='%d' stroke='black'/>\n", m, m, m, m + ph);
    fprintf(f, "<line x1='%d' y1='%d' x2='%d' y2='%d' stroke='black'/>\n", m, m + ph, m + pw, m + ph);

    // Title
    if (p->title[0])
        fprintf(f, "<text x='%d' y='%d' text-anchor='middle' font-size='16' font-weight='bold'>%s</text>\n",
                w / 2, 20, p->title);
    // Axis labels
    if (p->xlabel[0])
        fprintf(f, "<text x='%d' y='%d' text-anchor='middle' font-size='12'>%s</text>\n", w / 2, ht - 5, p->xlabel);
    if (p->ylabel[0])
        fprintf(f, "<text x='10' y='%d' text-anchor='middle' font-size='12' "
                   "transform='rotate(-90 10 %d)'>%s</text>\n", ht / 2, ht / 2, p->ylabel);

    // Tick marks
    for (int i = 0; i <= 5; i++) {
        double xv = xmin + i * xr / 5;
        int sx = SX(xv);
        fprintf(f, "<line x1='%d' y1='%d' x2='%d' y2='%d' stroke='#ccc'/>\n", sx, m, sx, m + ph);
        fprintf(f, "<text x='%d' y='%d' text-anchor='middle' font-size='10'>%.2g</text>\n", sx, m + ph + 15, xv);
    }
    for (int i = 0; i <= 5; i++) {
        double yv = ymin + i * yr / 5;
        int sy = SY(yv);
        fprintf(f, "<line x1='%d' y1='%d' x2='%d' y2='%d' stroke='#ccc'/>\n", m, sy, m + pw, sy);
        fprintf(f, "<text x='%d' y='%d' text-anchor='end' font-size='10'>%.2g</text>\n", m - 5, sy + 4, yv);
    }

    // Series
    for (int si = 0; si < p->n_series; si++) {
        PlotSeries *s = &p->series[si];
        if (s->type == PLOT_LINE) {
            fprintf(f, "<polyline fill='none' stroke='%s' stroke-width='2' points='", s->color);
            for (int i = 0; i < s->n; i++) fprintf(f, "%d,%d ", SX(s->xs[i]), SY(s->ys[i]));
            fprintf(f, "'/>\n");
        } else if (s->type == PLOT_SCATTER) {
            for (int i = 0; i < s->n; i++)
                fprintf(f, "<circle cx='%d' cy='%d' r='%.1f' fill='%s' opacity='0.7'/>\n",
                        SX(s->xs[i]), SY(s->ys[i]), s->size, s->color);
        } else if (s->type == PLOT_HEATMAP) {
            double gmin = s->grid[0], gmax = s->grid[0];
            int gn = s->grid_nx * s->grid_ny;
            for (int i = 1; i < gn; i++) { if (s->grid[i] < gmin) gmin = s->grid[i]; if (s->grid[i] > gmax) gmax = s->grid[i]; }
            double gr = (gmax - gmin > 1e-15) ? gmax - gmin : 1;
            double cw = (double)pw / s->grid_nx, ch_d = (double)ph / s->grid_ny;
            for (int iy = 0; iy < s->grid_ny; iy++) {
                for (int ix = 0; ix < s->grid_nx; ix++) {
                    double v = (s->grid[iy * s->grid_nx + ix] - gmin) / gr;
                    int r = (int)(255 * v), b = (int)(255 * (1 - v));
                    fprintf(f, "<rect x='%d' y='%d' width='%.1f' height='%.1f' fill='rgb(%d,0,%d)'/>\n",
                            m + (int)(ix * cw), m + (int)(iy * ch_d), cw + 1, ch_d + 1, r, b);
                }
            }
        }
    }

    // Legend
    if (p->show_legend) {
        int ly = m + 10;
        for (int si = 0; si < p->n_series; si++) {
            if (p->series[si].label[0]) {
                fprintf(f, "<rect x='%d' y='%d' width='20' height='10' fill='%s'/>\n",
                        m + pw - 100, ly, p->series[si].color);
                fprintf(f, "<text x='%d' y='%d' font-size='10'>%s</text>\n",
                        m + pw - 75, ly + 9, p->series[si].label);
                ly += 18;
            }
        }
    }

    fprintf(f, "</svg>\n");
    fclose(f);
    #undef SX
    #undef SY
}

void nuc_plot_free(long long h) {
    Plot *p = (Plot *)(void *)h;
    if (!p) return;
    for (int i = 0; i < p->n_series; i++) {
        free(p->series[i].xs); free(p->series[i].ys); free(p->series[i].grid);
    }
    free(p);
}
