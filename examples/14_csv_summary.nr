// 14_csv_summary.nr — End-to-end demo of the v0.2.x stdlib enrichment.
//
// Reads a CSV (bundled sample, or $NUC_CSV_PATH if set), parses integer
// columns, and prints per-column count / min / max / mean / median / stddev
// in a padded report.
//
// Demonstrates v0.2.x helpers from many releases:
//   v0.2.20  env_has, env_get, str_trim, str_to_i64
//   v0.2.24  int_to_str, f64_to_str, str_to_i64
//   v0.2.26  str_lines, str_pad_left, str_pad_right
//   v0.2.30  vec_mean_f64, vec_median_f64, vec_stddev_f64
//
// The bundled sample uses integer-scaled data (e.g. tenths of a degree)
// so the i64-based stats helpers operate cleanly. Real f64 columns can
// be loaded via NUC_CSV_PATH after preprocessing into integers.
//
// Build: nuc build examples/14_csv_summary.nr -o csv_summary
// Run:   ./csv_summary.exe
//        NUC_CSV_PATH=mydata.csv ./csv_summary.exe

fn read_csv_source() -> str {
    if env_has("NUC_CSV_PATH") == 1 {
        let path: str = env_get("NUC_CSV_PATH");
        if str_len(path) > 0 {
            return file_read_string(path);
        };
    };
    // Bundled sample: 7 rows, 3 columns. Values are integer-scaled
    // (temperature × 10, humidity × 10, pressure in tenths of hPa).
    return "temp_x10,humidity_x10,pressure_x10\n214,552,10131\n221,520,10143\n198,605,10107\n230,483,10159\n205,578,10124\n208,541,10118\n219,496,10135\n";
}

fn main() -> i64 {
    print("=== Nucleor CSV summary demo (v0.2.x stdlib) ===");

    let raw: str = read_csv_source();
    if str_len(raw) == 0 {
        print("ERROR: empty input");
        return 1;
    };

    let lines: Vec<str> = str_lines(raw);
    if vec_len(lines) < 2 {
        print("ERROR: need header + at least one data row");
        return 1;
    };

    let header: Vec<str> = str_split(vec_get(lines, 0), ",");
    let col_count: i64 = vec_len(header);

    // One column-vec per header.
    let columns: Vec<Vec<i64>> = vec_new();
    let mut c: i64 = 0;
    while c < col_count {
        let inner: Vec<i64> = vec_new();
        vec_push(columns, inner);
        c = c + 1;
    };

    let mut row_count: i64 = 0;
    let mut row_idx: i64 = 1;
    while row_idx < vec_len(lines) {
        let raw_line: str = vec_get(lines, row_idx);
        let trimmed: str = str_trim(raw_line);
        if str_len(trimmed) > 0 {
            let cells: Vec<str> = str_split(trimmed, ",");
            let mut k: i64 = 0;
            while k < col_count {
                if k < vec_len(cells) {
                    let cell: str = str_trim(vec_get(cells, k));
                    vec_push(vec_get(columns, k), str_to_i64(cell));
                };
                k = k + 1;
            };
            row_count = row_count + 1;
        };
        row_idx = row_idx + 1;
    };

    // Header row: pad each cell to a fixed width.
    print("");
    let pad: i64 = 16;
    let mut head_line: str = str_pad_right("metric", pad, 32);
    let mut h: i64 = 0;
    while h < col_count {
        head_line = str_concat(head_line, str_pad_left(vec_get(header, h), pad, 32));
        h = h + 1;
    };
    print(head_line);

    // Underline
    let mut bar: str = "";
    let mut b: i64 = 0;
    let total_width: i64 = pad * (col_count + 1);
    while b < total_width {
        bar = str_concat(bar, "-");
        b = b + 1;
    };
    print(bar);

    // Each row of the report = one statistic across all columns.
    let metrics: Vec<str> = vec_new();
    vec_push(metrics, "count");
    vec_push(metrics, "min");
    vec_push(metrics, "max");
    vec_push(metrics, "range");
    vec_push(metrics, "mean");
    vec_push(metrics, "median");
    vec_push(metrics, "stddev");

    let mut m: i64 = 0;
    while m < vec_len(metrics) {
        let metric: str = vec_get(metrics, m);
        let mut line: str = str_pad_right(metric, pad, 32);
        let mut col: i64 = 0;
        while col < col_count {
            let v: Vec<i64> = vec_get(columns, col);
            let mut val_str: str = "";
            if str_eq(metric, "count") == 1 {
                val_str = int_to_str(vec_len(v));
            } else if str_eq(metric, "min") == 1 {
                val_str = int_to_str(vec_min_i64(v));
            } else if str_eq(metric, "max") == 1 {
                val_str = int_to_str(vec_max_i64(v));
            } else if str_eq(metric, "range") == 1 {
                val_str = int_to_str(vec_range_i64(v));
            } else if str_eq(metric, "mean") == 1 {
                val_str = f64_to_str(vec_mean_f64(v));
            } else if str_eq(metric, "median") == 1 {
                val_str = f64_to_str(vec_median_f64(v));
            } else if str_eq(metric, "stddev") == 1 {
                val_str = f64_to_str(vec_stddev_f64(v));
            };
            line = str_concat(line, str_pad_left(val_str, pad, 32));
            col = col + 1;
        };
        print(line);
        m = m + 1;
    };

    print("");
    print(str_concat(str_concat("Processed ", int_to_str(row_count)), " rows."));
    return 0;
}
