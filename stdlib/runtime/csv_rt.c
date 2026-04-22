// csv_rt.c — CSV Reading and Writing for Nucleor
// Parse CSV files, access cells as string/float, create and write tables.
//
// Compile: clang -c stdlib/runtime/csv_rt.c -o target/csv_rt.obj -O2

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static double _cs_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _cs_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct {
    char **cells;  // flat [rows * cols]
    int rows, cols;
} CSVTable;

// ================================================================
//  CSV Read
// ================================================================

long long nuc_csv_read(const char *path) {
    if (!path) return 0;
    FILE *f = fopen(path, "rb");
    if (!f) return 0;

    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *buf = (char *)malloc(sz + 1);
    fread(buf, 1, sz, f);
    fclose(f);
    buf[sz] = 0;

    // Count rows and cols
    int rows = 0, cols = 0;
    int cur_cols = 1;
    for (long i = 0; i < sz; i++) {
        if (buf[i] == ',') cur_cols++;
        if (buf[i] == '\n' || buf[i] == '\r') {
            if (cur_cols > cols) cols = cur_cols;
            rows++;
            cur_cols = 1;
            if (buf[i] == '\r' && i + 1 < sz && buf[i + 1] == '\n') i++;
        }
    }
    if (sz > 0 && buf[sz - 1] != '\n') rows++; // last line without newline

    CSVTable *table = (CSVTable *)malloc(sizeof(CSVTable));
    table->rows = rows;
    table->cols = cols;
    table->cells = (char **)calloc(rows * cols, sizeof(char *));

    // Parse cells
    int row = 0, col = 0;
    long start = 0;
    for (long i = 0; i <= sz; i++) {
        int is_end = (i == sz || buf[i] == ',' || buf[i] == '\n' || buf[i] == '\r');
        if (is_end && row < rows) {
            long end = i;
            // Trim whitespace
            while (start < end && (buf[start] == ' ' || buf[start] == '\t')) start++;
            while (end > start && (buf[end - 1] == ' ' || buf[end - 1] == '\t')) end--;
            // Strip quotes
            if (end > start && buf[start] == '"' && buf[end - 1] == '"') { start++; end--; }

            int len = (int)(end - start);
            if (col < cols) {
                table->cells[row * cols + col] = (char *)malloc(len + 1);
                memcpy(table->cells[row * cols + col], buf + start, len);
                table->cells[row * cols + col][len] = 0;
            }

            if (buf[i] == ',') {
                col++;
            } else {
                col = 0;
                row++;
                if (buf[i] == '\r' && i + 1 <= sz && buf[i + 1] == '\n') i++;
            }
            start = i + 1;
        }
    }

    // Fill NULL cells with empty strings
    for (int i = 0; i < rows * cols; i++) {
        if (!table->cells[i]) {
            table->cells[i] = (char *)malloc(1);
            table->cells[i][0] = 0;
        }
    }

    free(buf);
    return (long long)table;
}

// ================================================================
//  Accessors
// ================================================================

const char *nuc_csv_get(long long th, long long row, long long col) {
    CSVTable *t = (CSVTable *)(void *)th;
    if (!t || (int)row >= t->rows || (int)col >= t->cols) return "";
    char *cell = t->cells[(int)row * t->cols + (int)col];
    return cell ? cell : "";
}

long long nuc_csv_get_float(long long th, long long row, long long col) {
    const char *s = nuc_csv_get(th, row, col);
    return _cs_f2i(atof(s));
}

long long nuc_csv_get_int(long long th, long long row, long long col) {
    const char *s = nuc_csv_get(th, row, col);
    return atoll(s);
}

long long nuc_csv_rows(long long th) { return ((CSVTable *)(void *)th)->rows; }
long long nuc_csv_cols(long long th) { return ((CSVTable *)(void *)th)->cols; }

// ================================================================
//  Creation and Writing
// ================================================================

long long nuc_csv_new(long long rows, long long cols) {
    CSVTable *t = (CSVTable *)malloc(sizeof(CSVTable));
    t->rows = (int)rows; t->cols = (int)cols;
    t->cells = (char **)calloc(t->rows * t->cols, sizeof(char *));
    for (int i = 0; i < t->rows * t->cols; i++) {
        t->cells[i] = (char *)malloc(1);
        t->cells[i][0] = 0;
    }
    return (long long)t;
}

void nuc_csv_set(long long th, long long row, long long col, const char *val) {
    CSVTable *t = (CSVTable *)(void *)th;
    if (!t || !val) return;
    int idx = (int)row * t->cols + (int)col;
    if (idx < 0 || idx >= t->rows * t->cols) return;
    free(t->cells[idx]);
    t->cells[idx] = (char *)malloc(strlen(val) + 1);
    strcpy(t->cells[idx], val);
}

void nuc_csv_set_float(long long th, long long row, long long col, long long val_bits) {
    char buf[64];
    double v;
    memcpy(&v, &val_bits, 8);
    snprintf(buf, 64, "%.6f", v);
    nuc_csv_set(th, row, col, buf);
}

void nuc_csv_write(long long th, const char *path) {
    CSVTable *t = (CSVTable *)(void *)th;
    if (!t || !path) return;
    FILE *f = fopen(path, "wb");
    if (!f) return;
    for (int i = 0; i < t->rows; i++) {
        for (int j = 0; j < t->cols; j++) {
            if (j > 0) fputc(',', f);
            const char *cell = t->cells[i * t->cols + j];
            // Quote if contains comma or newline
            int needs_quote = 0;
            for (const char *p = cell; *p; p++)
                if (*p == ',' || *p == '\n' || *p == '"') { needs_quote = 1; break; }
            if (needs_quote) {
                fputc('"', f);
                for (const char *p = cell; *p; p++) {
                    if (*p == '"') fputc('"', f);
                    fputc(*p, f);
                }
                fputc('"', f);
            } else {
                fputs(cell, f);
            }
        }
        fputc('\n', f);
    }
    fclose(f);
}

void nuc_csv_free(long long th) {
    CSVTable *t = (CSVTable *)(void *)th;
    if (!t) return;
    for (int i = 0; i < t->rows * t->cols; i++) free(t->cells[i]);
    free(t->cells); free(t);
}
