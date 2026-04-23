// rods/csv_table — Whole-CSV-file table API (load, set, write, free)
//
// `csv.nr` is the line-by-line streaming parser. This rod is the
// table-as-value sibling: load a whole file into memory, address
// cells by `(row, col)`, write the table back out. Useful when the
// access pattern is random rather than streaming.
//
// `csv_get_float` / `csv_set_float` use i64-encoded float bits
// (reinterpret cast) so the wrapper stays scalar; convert at the
// call site with the standard f64-bits builtins.
//
// See `stdlib/runtime/csv_rt.c`.
#cfile "../runtime/csv_rt.c"

extern fn nuc_csv_read(path: str) -> i64;
extern fn nuc_csv_get_float(th: i64, row: i64, col: i64) -> i64;
extern fn nuc_csv_get_int(th: i64, row: i64, col: i64) -> i64;
extern fn nuc_csv_rows(th: i64) -> i64;
extern fn nuc_csv_cols(th: i64) -> i64;
extern fn nuc_csv_new(rows: i64, cols: i64) -> i64;
extern fn nuc_csv_set(th: i64, row: i64, col: i64, val: str);
extern fn nuc_csv_set_float(th: i64, row: i64, col: i64, val_bits: i64);
extern fn nuc_csv_write(th: i64, path: str);
extern fn nuc_csv_free(th: i64);

fn csv_table_read(path: str) -> i64 { return nuc_csv_read(path); }
fn csv_table_new(rows: i64, cols: i64) -> i64 { return nuc_csv_new(rows, cols); }
fn csv_table_get_int(t: i64, r: i64, c: i64) -> i64 {
    return nuc_csv_get_int(t, r, c);
}
fn csv_table_get_float(t: i64, r: i64, c: i64) -> i64 {
    return nuc_csv_get_float(t, r, c);
}
fn csv_table_rows(t: i64) -> i64 { return nuc_csv_rows(t); }
fn csv_table_cols(t: i64) -> i64 { return nuc_csv_cols(t); }
fn csv_table_set(t: i64, r: i64, c: i64, val: str) {
    nuc_csv_set(t, r, c, val);
}
fn csv_table_set_float(t: i64, r: i64, c: i64, val_bits: i64) {
    nuc_csv_set_float(t, r, c, val_bits);
}
fn csv_table_write(t: i64, path: str) { nuc_csv_write(t, path); }
fn csv_table_free(t: i64) { nuc_csv_free(t); }
