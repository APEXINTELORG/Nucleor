// rods/io runtime — I/O primitives for Nucleor
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

const char *rods_io_read_line(void) {
    char buf[4096];
    if (fgets(buf, sizeof(buf), stdin)) {
        int len = (int)strlen(buf);
        // Strip trailing newline
        while (len > 0 && (buf[len-1] == '\n' || buf[len-1] == '\r')) {
            buf[--len] = '\0';
        }
        char *result = (char *)malloc(len + 1);
        memcpy(result, buf, len + 1);
        return result;
    }
    return "";
}

// v0.8.152 V1.16 Phase A1 dependency — raw N-byte stdin read.
//
// LSP base protocol frames JSON-RPC payloads with a Content-
// Length header followed by exactly N body bytes. fgets/read_line
// strip newlines and break on LF, so they can't faithfully read
// the JSON body (which embeds newlines inside string values).
//
// rods_io_read_n_bytes reads exactly `n` bytes from stdin into a
// freshly malloc'd null-terminated buffer. Stops short on EOF
// (returned string is shorter than `n`). Caller frees via the
// usual nucleor str-handle path. Returns "" on n <= 0.
const char *rods_io_read_n_bytes(long long n) {
    if (n <= 0) return "";
    char *buf = (char *)malloc((size_t)n + 1);
    if (!buf) return "";
    long long got = 0;
    while (got < n) {
        size_t r = fread(buf + got, 1, (size_t)(n - got), stdin);
        if (r == 0) break;
        got += (long long)r;
    }
    buf[got] = '\0';
    return buf;
}

void rods_io_print_no_newline(const char *s) {
    if (s) {
        printf("%s", s);
        fflush(stdout);
    }
}

void rods_io_eprint(const char *s) {
    if (s) {
        fprintf(stderr, "%s\n", s);
        fflush(stderr);
    }
}

// =====================================================
// CSV Parser for QuBound dataset
// =====================================================
// Loads a CSV file, returns data as flat Vec of f64 values
// Skips header row. Each row becomes n_cols consecutive f64 values.
// Returns: [data_vec, n_rows] where data_vec is flat n_rows * n_cols

static double _csv_i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _csv_f2i(double f) { long long i; memcpy(&i, &f, sizeof(long long)); return i; }

typedef struct { long long *data; int len; int cap; } CSVVec;
static void csv_push(CSVVec *v, long long val) {
    if (v->len >= v->cap) {
        v->cap = v->cap * 2 + 16;
        v->data = (long long *)realloc(v->data, v->cap * sizeof(long long));
    }
    v->data[v->len++] = val;
}

// Load CSV file, return Vec of f64 values (flat: n_rows * n_cols)
// path: file path string, skip_header: 1 to skip first row
// Returns Vec, sets *out_n_rows
long long nuc_csv_load(const char *path, long long n_cols_expected, long long skip_header) {
    FILE *f = fopen(path, "r");
    if (!f) {
        fprintf(stderr, "csv_load: cannot open %s\n", path);
        CSVVec *empty = (CSVVec *)malloc(sizeof(CSVVec));
        empty->len = 0; empty->cap = 1;
        empty->data = (long long *)malloc(sizeof(long long));
        return (long long)empty;
    }

    CSVVec *result = (CSVVec *)malloc(sizeof(CSVVec));
    result->len = 0; result->cap = 1024;
    result->data = (long long *)malloc(result->cap * sizeof(long long));

    char line[8192];
    int line_num = 0;
    int n_cols = (int)n_cols_expected;
    int n_rows = 0;

    while (fgets(line, sizeof(line), f)) {
        line_num++;
        if (skip_header && line_num == 1) continue;

        // Parse comma-separated values
        char *ptr = line;
        int col = 0;
        while (*ptr && col < n_cols) {
            // Skip whitespace
            while (*ptr == ' ' || *ptr == '\t') ptr++;
            if (*ptr == '\0' || *ptr == '\n' || *ptr == '\r') break;

            // Parse number
            char *end;
            double val = strtod(ptr, &end);
            if (end == ptr) {
                // Not a number — skip this field
                while (*ptr && *ptr != ',' && *ptr != '\n' && *ptr != '\r') ptr++;
                val = 0.0;
            } else {
                ptr = end;
            }
            csv_push(result, _csv_f2i(val));
            col++;

            // Skip comma
            if (*ptr == ',') ptr++;
        }

        // Pad remaining columns with 0
        while (col < n_cols) {
            csv_push(result, _csv_f2i(0.0));
            col++;
        }

        if (col > 0) n_rows++;
    }

    fclose(f);

    // Append row count as last element
    csv_push(result, (long long)n_rows);

    return (long long)result;
}

// Get number of rows from loaded CSV (last element)
long long nuc_csv_n_rows(long long csv_handle) {
    CSVVec *v = (CSVVec *)(void *)csv_handle;
    if (!v || v->len == 0) return 0;
    return v->data[v->len - 1];
}

// Get a value from loaded CSV: row * n_cols + col
long long nuc_csv_get(long long csv_handle, long long row, long long col, long long n_cols) {
    CSVVec *v = (CSVVec *)(void *)csv_handle;
    int idx = (int)(row * n_cols + col);
    if (idx < 0 || idx >= v->len - 1) return _csv_f2i(0.0); // -1 because last element is n_rows
    return v->data[idx];
}
