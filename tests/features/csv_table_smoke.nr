// v0.8.124 stdlib/rods/csv_table.nr first test coverage.
//
// Sister to v0.8.105's csv.nr coverage. csv_table is the
// whole-file random-access API (load file → cell get/set →
// write file), distinct from csv.nr's streaming line parser.
//
// Locks:
//   1. csv_table_new dimensions: rows + cols round-trip.
//   2. csv_table_set + read-back via int/float getter.
//   3. write to disk + read back: dimensions + cells preserve.
//   4. csv_table_set_float / get_float bits round-trip.
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/csv_table.nr"
import "stdlib/rods/fs.nr"

fn close(a: i64, b: i64) -> i64 {
    let af: f64 = f64_from_bits(a);
    let bf: f64 = f64_from_bits(b);
    let diff: f64 = af - bf;
    let abs_diff: f64 = if diff < 0.0 { 0.0 - diff } else { diff };
    if abs_diff < 1e-6 { return 1; };
    return 0;
}

fn check_new_dimensions() -> i64 {
    let t: i64 = csv_table_new(3, 4);
    let r: i64 = csv_table_rows(t);
    let c: i64 = csv_table_cols(t);
    csv_table_free(t);
    if r != 3 { return 1; };
    if c != 4 { return 2; };
    return 0;
}

fn check_set_get_int() -> i64 {
    let t: i64 = csv_table_new(2, 2);
    csv_table_set(t, 0, 0, "10");
    csv_table_set(t, 0, 1, "20");
    csv_table_set(t, 1, 0, "30");
    csv_table_set(t, 1, 1, "40");
    let v00: i64 = csv_table_get_int(t, 0, 0);
    let v11: i64 = csv_table_get_int(t, 1, 1);
    csv_table_free(t);
    if v00 != 10 { return 4; };
    if v11 != 40 { return 8; };
    return 0;
}

fn check_set_get_float() -> i64 {
    let t: i64 = csv_table_new(2, 2);
    csv_table_set_float(t, 0, 0, f64_to_bits(3.14));
    csv_table_set_float(t, 1, 1, f64_to_bits(2.718));
    let r00: i64 = csv_table_get_float(t, 0, 0);
    let r11: i64 = csv_table_get_float(t, 1, 1);
    csv_table_free(t);
    if close(r00, f64_to_bits(3.14)) != 1 { return 16; };
    if close(r11, f64_to_bits(2.718)) != 1 { return 32; };
    return 0;
}

fn check_write_read_round_trip() -> i64 {
    let path: str = "target/_csv_table_smoke.csv";
    let t: i64 = csv_table_new(2, 3);
    csv_table_set(t, 0, 0, "a");
    csv_table_set(t, 0, 1, "1");
    csv_table_set(t, 0, 2, "2");
    csv_table_set(t, 1, 0, "b");
    csv_table_set(t, 1, 1, "3");
    csv_table_set(t, 1, 2, "4");
    csv_table_write(t, path);
    csv_table_free(t);

    let t2: i64 = csv_table_read(path);
    if t2 == 0 { return 64; };
    let r: i64 = csv_table_rows(t2);
    let c: i64 = csv_table_cols(t2);
    let v01: i64 = csv_table_get_int(t2, 0, 1);
    let v12: i64 = csv_table_get_int(t2, 1, 2);
    csv_table_free(t2);
    fs_remove(path);
    if r != 2 { return 128; };
    if c != 3 { return 256; };
    if v01 != 1 { return 512; };
    if v12 != 4 { return 1024; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_new_dimensions();
    fails = fails + check_set_get_int();
    fails = fails + check_set_get_float();
    fails = fails + check_write_read_round_trip();
    return fails;
}
