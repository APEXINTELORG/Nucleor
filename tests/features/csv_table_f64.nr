// stdlib/rods/csv_table — `*_f64` ergonomic wrappers.
//
// v0.4.263 bundle (with kdt). Round-trip a 2x2 numeric table
// purely via the f64 surface, no f64_to_bits/from_bits at the
// call site.
//
// EXPECT: build success, runtime exit 0, output "OK csv_table_f64".

import "stdlib/rods/csv_table.nr"

fn main() -> i32 {
    let t: i64 = csv_table_new(2, 2);

    csv_table_set_f64(t, 0, 0, 1.5);
    csv_table_set_f64(t, 0, 1, 2.5);
    csv_table_set_f64(t, 1, 0, 3.5);
    csv_table_set_f64(t, 1, 1, 4.5);

    // Read back via _f64 getter — multiply by 2 to widen
    // before integer comparison (avoids losing the 0.5 fraction).
    if ((csv_table_get_f64(t, 0, 0) * 2.0) as i32) != 3 { print("FAIL get(0,0)"); return 1; };
    if ((csv_table_get_f64(t, 0, 1) * 2.0) as i32) != 5 { print("FAIL get(0,1)"); return 1; };
    if ((csv_table_get_f64(t, 1, 0) * 2.0) as i32) != 7 { print("FAIL get(1,0)"); return 1; };
    if ((csv_table_get_f64(t, 1, 1) * 2.0) as i32) != 9 { print("FAIL get(1,1)"); return 1; };

    csv_table_free(t);

    print("OK csv_table_f64");
    0
}
