// 16_histogram.nr — ASCII histogram of numeric data exercising the v0.2.x stdlib.
//
// Reads one number per line from $NUC_HIST_PATH (or a bundled sample),
// buckets them into a fixed number of bins between observed min/max, and
// prints an ASCII bar chart with one row per bucket.
//
// Demonstrates:
//   v0.2.19  fs_temp_dir (informational)
//   v0.2.20  env_has, env_get, str_trim, str_is_empty
//   v0.2.24  str_to_i64, int_to_str, f64_to_str
//   v0.2.26  str_lines, str_pad_right, str_pad_left, str_chars (unused
//            but typical companion)
//   v0.2.30  vec_min_i64, vec_max_i64, vec_range_i64, vec_mean_f64,
//            vec_median_f64, vec_stddev_f64
//
// Build: nuc build examples/16_histogram.nr -o histogram
// Run:   ./histogram.exe                     # bundled sample
//        NUC_HIST_PATH=mydata.txt ./histogram.exe

fn read_data_source() -> str {
    if env_has("NUC_HIST_PATH") == 1 {
        let path: str = env_get("NUC_HIST_PATH");
        if str_len(path) > 0 {
            return file_read_string(path);
        };
    };
    // Bundled sample: 30 integers roughly normally distributed around 50.
    return "42\n51\n47\n55\n49\n38\n52\n44\n58\n50\n46\n53\n41\n49\n54\n48\n50\n45\n57\n43\n51\n47\n49\n52\n48\n44\n56\n50\n45\n53\n";
}

fn parse_numbers(raw: str) -> Vec<i64> {
    let lines: Vec<str> = str_lines(raw);
    let out: Vec<i64> = vec_new();
    let mut i: i64 = 0;
    while i < vec_len(lines) {
        let line: str = str_trim(vec_get(lines, i));
        if str_is_empty(line) == 0 {
            vec_push(out, str_to_i64(line));
        };
        i = i + 1;
    };
    return out;
}

fn make_bar(count: i64, max_count: i64, width: i64) -> str {
    if max_count <= 0 || count <= 0 { return ""; };
    let len: i64 = (count * width) / max_count;
    let mut bar: str = "";
    let mut i: i64 = 0;
    while i < len {
        bar = str_concat(bar, "#");
        i = i + 1;
    };
    return bar;
}

fn main() -> i64 {
    print("=== Nucleor histogram demo (v0.2.x stdlib) ===");

    let raw: str = read_data_source();
    let nums: Vec<i64> = parse_numbers(raw);
    let n: i64 = vec_len(nums);
    if n == 0 {
        print("ERROR: no numeric input");
        return 1;
    };

    let mn: i64 = vec_min_i64(nums);
    let mx: i64 = vec_max_i64(nums);
    let rng: i64 = vec_range_i64(nums);

    print("");
    print(str_concat(str_concat("Samples:  ", int_to_str(n)), ""));
    print(str_concat(str_concat("Min:      ", int_to_str(mn)), ""));
    print(str_concat(str_concat("Max:      ", int_to_str(mx)), ""));
    print(str_concat(str_concat("Range:    ", int_to_str(rng)), ""));
    print(str_concat(str_concat("Mean:     ", f64_to_str(vec_mean_f64(nums))), ""));
    print(str_concat(str_concat("Median:   ", f64_to_str(vec_median_f64(nums))), ""));
    print(str_concat(str_concat("StdDev:   ", f64_to_str(vec_stddev_f64(nums))), ""));

    // Build BIN_COUNT-bucket histogram. Bucket width = (max - min) / BIN_COUNT
    // (rounded up). Bin index = (value - min) / width, clamped to [0, BIN_COUNT-1].
    let bin_count: i64 = 10;
    let bins: Vec<i64> = vec_new();
    let mut b: i64 = 0;
    while b < bin_count { vec_push(bins, 0); b = b + 1; };

    let width: i64 = if rng == 0 { 1 } else { (rng + bin_count - 1) / bin_count };
    let mut i: i64 = 0;
    while i < n {
        let v: i64 = vec_get(nums, i);
        let mut idx: i64 = (v - mn) / width;
        if idx < 0 { idx = 0; };
        if idx >= bin_count { idx = bin_count - 1; };
        vec_set(bins, idx, vec_get(bins, idx) + 1);
        i = i + 1;
    };

    // Find tallest bin for bar scaling
    let mut max_count: i64 = 0;
    let mut k: i64 = 0;
    while k < bin_count {
        let c: i64 = vec_get(bins, k);
        if c > max_count { max_count = c; };
        k = k + 1;
    };

    print("");
    print("Distribution:");
    print("range            count  bar");
    print("--------------------------------");

    let bar_width: i64 = 40;
    let mut j: i64 = 0;
    while j < bin_count {
        let lo: i64 = mn + j * width;
        let hi: i64 = if j == bin_count - 1 { mx } else { lo + width - 1 };
        let count: i64 = vec_get(bins, j);
        let label: str = str_concat(str_concat(int_to_str(lo), "-"), int_to_str(hi));
        let bar: str = make_bar(count, max_count, bar_width);
        let line: str = str_concat(
            str_concat(str_pad_right(label, 16, 32), str_pad_left(int_to_str(count), 6, 32)),
            str_concat("  ", bar)
        );
        print(line);
        j = j + 1;
    };
    return 0;
}
