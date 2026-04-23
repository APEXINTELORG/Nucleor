// rods/csv_table — verify rod wrapper compiles + links (v0.2.150 wrap)
import "stdlib/rods/csv_table.nr"

fn main() -> i64 {
    let t: i64 = csv_table_new(3, 2);
    if t == 0 { print("FAIL csv_table_new"); return 1; };
    csv_table_set(t, 0, 0, "a");
    csv_table_set(t, 0, 1, "b");
    if csv_table_rows(t) != 3 { print("FAIL csv_table_rows"); return 1; };
    if csv_table_cols(t) != 2 { print("FAIL csv_table_cols"); return 1; };
    csv_table_free(t);
    print("OK csv_table_smoke");
    return 0;
}
