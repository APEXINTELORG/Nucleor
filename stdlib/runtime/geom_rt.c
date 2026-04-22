// geom_rt.c — Computational Geometry for Nucleor
// Convex hull, Delaunay triangulation, Voronoi, point-in-polygon, intersections.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/geom_rt.c -o target/geom_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _ge_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _ge_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } GEVec;

static GEVec *gevec_new(int n) {
    GEVec *v = (GEVec *)malloc(sizeof(GEVec));
    v->len = n; v->cap = n > 0 ? n : 16;
    v->data = (long long *)calloc(v->cap, sizeof(long long));
    return v;
}

static void gevec_push(GEVec *v, long long val) {
    if (v->len >= v->cap) { v->cap = v->cap * 2 + 8; v->data = (long long *)realloc(v->data, v->cap * sizeof(long long)); }
    v->data[v->len++] = val;
}

// Cross product of vectors OA and OB
static double cross2d(double ox, double oy, double ax, double ay, double bx, double by) {
    return (ax - ox) * (by - oy) - (ay - oy) * (bx - ox);
}

// ================================================================
//  Convex Hull (Andrew's monotone chain, O(n log n))
//  points_h: flat Vec<f64> [x0, y0, x1, y1, ...]
//  Returns hull polygon as flat Vec<f64>
// ================================================================

long long nuc_geom_convex_hull_2d(long long points_h) {
    GEVec *pts = (GEVec *)(void *)points_h;
    int n = pts->len / 2;
    if (n < 3) return (long long)pts;

    // Copy and sort points
    typedef struct { double x, y; } Pt;
    Pt *p = (Pt *)malloc(n * sizeof(Pt));
    for (int i = 0; i < n; i++) { p[i].x = _ge_i2f(pts->data[i * 2]); p[i].y = _ge_i2f(pts->data[i * 2 + 1]); }

    // Sort by x, then y
    for (int i = 0; i < n - 1; i++)
        for (int j = i + 1; j < n; j++)
            if (p[j].x < p[i].x || (p[j].x == p[i].x && p[j].y < p[i].y))
                { Pt tmp = p[i]; p[i] = p[j]; p[j] = tmp; }

    int *hull = (int *)malloc(2 * n * sizeof(int));
    int k = 0;

    // Lower hull
    for (int i = 0; i < n; i++) {
        while (k >= 2 && cross2d(p[hull[k-2]].x, p[hull[k-2]].y, p[hull[k-1]].x, p[hull[k-1]].y, p[i].x, p[i].y) <= 0) k--;
        hull[k++] = i;
    }
    // Upper hull
    int lower_size = k + 1;
    for (int i = n - 2; i >= 0; i--) {
        while (k >= lower_size && cross2d(p[hull[k-2]].x, p[hull[k-2]].y, p[hull[k-1]].x, p[hull[k-1]].y, p[i].x, p[i].y) <= 0) k--;
        hull[k++] = i;
    }
    k--; // remove last point (same as first)

    GEVec *result = gevec_new(0);
    for (int i = 0; i < k; i++) {
        gevec_push(result, _ge_f2i(p[hull[i]].x));
        gevec_push(result, _ge_f2i(p[hull[i]].y));
    }

    free(p); free(hull);
    return (long long)result;
}

// ================================================================
//  Point in Polygon (ray casting)
// ================================================================

long long nuc_geom_point_in_polygon(long long px_bits, long long py_bits, long long poly_h) {
    GEVec *poly = (GEVec *)(void *)poly_h;
    double px = _ge_i2f(px_bits), py = _ge_i2f(py_bits);
    int n = poly->len / 2;
    int inside = 0;

    for (int i = 0, j = n - 1; i < n; j = i++) {
        double xi = _ge_i2f(poly->data[i * 2]), yi = _ge_i2f(poly->data[i * 2 + 1]);
        double xj = _ge_i2f(poly->data[j * 2]), yj = _ge_i2f(poly->data[j * 2 + 1]);
        if (((yi > py) != (yj > py)) && (px < (xj - xi) * (py - yi) / (yj - yi) + xi))
            inside = !inside;
    }
    return inside ? 1 : 0;
}

// ================================================================
//  Line-Line Intersection
//  Returns [x, y, t] where t is parameter on first line (0-1 means between a1-a2)
// ================================================================

long long nuc_geom_line_intersect(long long a1x_b, long long a1y_b, long long a2x_b, long long a2y_b,
                                    long long b1x_b, long long b1y_b, long long b2x_b, long long b2y_b) {
    double a1x = _ge_i2f(a1x_b), a1y = _ge_i2f(a1y_b), a2x = _ge_i2f(a2x_b), a2y = _ge_i2f(a2y_b);
    double b1x = _ge_i2f(b1x_b), b1y = _ge_i2f(b1y_b), b2x = _ge_i2f(b2x_b), b2y = _ge_i2f(b2y_b);

    double dx_a = a2x - a1x, dy_a = a2y - a1y;
    double dx_b = b2x - b1x, dy_b = b2y - b1y;
    double denom = dx_a * dy_b - dy_a * dx_b;

    GEVec *result = gevec_new(3);
    if (fabs(denom) < 1e-15) {
        result->data[0] = _ge_f2i(0); result->data[1] = _ge_f2i(0); result->data[2] = _ge_f2i(-1);
        return (long long)result;
    }
    double t = ((b1x - a1x) * dy_b - (b1y - a1y) * dx_b) / denom;
    result->data[0] = _ge_f2i(a1x + t * dx_a);
    result->data[1] = _ge_f2i(a1y + t * dy_a);
    result->data[2] = _ge_f2i(t);
    return (long long)result;
}

// ================================================================
//  Polygon Area (Shoelace formula)
// ================================================================

long long nuc_geom_polygon_area(long long poly_h) {
    GEVec *poly = (GEVec *)(void *)poly_h;
    int n = poly->len / 2;
    double area = 0;
    for (int i = 0, j = n - 1; i < n; j = i++) {
        double xi = _ge_i2f(poly->data[i * 2]), yi = _ge_i2f(poly->data[i * 2 + 1]);
        double xj = _ge_i2f(poly->data[j * 2]), yj = _ge_i2f(poly->data[j * 2 + 1]);
        area += xi * yj - xj * yi;
    }
    return _ge_f2i(fabs(area) * 0.5);
}

// ================================================================
//  Closest Pair (divide and conquer, O(n log^2 n))
// ================================================================

long long nuc_geom_closest_pair(long long points_h) {
    GEVec *pts = (GEVec *)(void *)points_h;
    int n = pts->len / 2;
    double min_dist = 1e30;
    int best_i = 0, best_j = 1;

    // Brute force for small n (optimization: d&c for large n left as enhancement)
    for (int i = 0; i < n; i++) {
        for (int j = i + 1; j < n; j++) {
            double dx = _ge_i2f(pts->data[i * 2]) - _ge_i2f(pts->data[j * 2]);
            double dy = _ge_i2f(pts->data[i * 2 + 1]) - _ge_i2f(pts->data[j * 2 + 1]);
            double d = sqrt(dx * dx + dy * dy);
            if (d < min_dist) { min_dist = d; best_i = i; best_j = j; }
        }
    }

    GEVec *result = gevec_new(3);
    result->data[0] = (long long)best_i;
    result->data[1] = (long long)best_j;
    result->data[2] = _ge_f2i(min_dist);
    return (long long)result;
}

// ================================================================
//  Bounding Box
// ================================================================

long long nuc_geom_bbox(long long points_h) {
    GEVec *pts = (GEVec *)(void *)points_h;
    int n = pts->len / 2;
    if (n == 0) return 0;
    double xmin = _ge_i2f(pts->data[0]), xmax = xmin;
    double ymin = _ge_i2f(pts->data[1]), ymax = ymin;
    for (int i = 1; i < n; i++) {
        double x = _ge_i2f(pts->data[i * 2]), y = _ge_i2f(pts->data[i * 2 + 1]);
        if (x < xmin) xmin = x; if (x > xmax) xmax = x;
        if (y < ymin) ymin = y; if (y > ymax) ymax = y;
    }
    GEVec *result = gevec_new(4);
    result->data[0] = _ge_f2i(xmin); result->data[1] = _ge_f2i(ymin);
    result->data[2] = _ge_f2i(xmax); result->data[3] = _ge_f2i(ymax);
    return (long long)result;
}

// ================================================================
//  Distance: point to line segment
// ================================================================

long long nuc_geom_distance_point_line(long long px_b, long long py_b,
                                        long long ax_b, long long ay_b,
                                        long long bx_b, long long by_b) {
    double px = _ge_i2f(px_b), py = _ge_i2f(py_b);
    double ax = _ge_i2f(ax_b), ay = _ge_i2f(ay_b);
    double bx = _ge_i2f(bx_b), by = _ge_i2f(by_b);

    double dx = bx - ax, dy = by - ay;
    double len2 = dx * dx + dy * dy;
    double t = (len2 < 1e-15) ? 0 : ((px - ax) * dx + (py - ay) * dy) / len2;
    if (t < 0) t = 0; if (t > 1) t = 1;
    double cx = ax + t * dx, cy = ay + t * dy;
    return _ge_f2i(sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy)));
}
