// rods/ml/data_facade — pandas-style FrameI64F64 + nullable variant + 100+ pandas-deep parity helpers (cumsum/cumprod/cummax/cummin/diff/abs/clip/expanding/groupby/sort/describe/rank)
//
import "stdlib/rods/ml/dtype_core.nr"
import "stdlib/rods/ml/tensor_facade.nr"

// data_facade.nr - first pandas-style typed data facade.
//
// This starts with a narrow, deterministic CSV frame so pandas parity can land
// before the full schema/columnar engine exists.

#[repr(C)]
struct FrameI64F64 {
    key_name: str,
    value_name: str,
    rows: i64,
    keys: Vec<i64>,
    values: Vec<f64>
}

#[repr(C)]
struct FrameI64NullableF64 {
    key_name: str,
    value_name: str,
    rows: i64,
    keys: Vec<i64>,
    values: Vec<f64>,
    valid: Vec<i64>
}

#[repr(C)]
struct FrameStrF64 {
    key_name: str,
    value_name: str,
    rows: i64,
    keys: Vec<str>,
    values: Vec<f64>
}

#[repr(C)]
struct FrameStrNullableF64 {
    key_name: str,
    value_name: str,
    rows: i64,
    keys: Vec<str>,
    values: Vec<f64>,
    valid: Vec<i64>
}

#[repr(C)]
struct FrameI64F64F64 {
    key_name: str,
    value0_name: str,
    value1_name: str,
    rows: i64,
    keys: Vec<i64>,
    values0: Vec<f64>,
    values1: Vec<f64>
}

#[repr(C)]
struct GroupedI64F64 {
    groups: i64,
    keys: Vec<i64>,
    sums: Vec<f64>,
    counts: Vec<i64>
}

#[repr(C)]
struct GroupedStatsI64F64 {
    groups: i64,
    keys: Vec<i64>,
    counts: Vec<i64>,
    mins: Vec<f64>,
    maxs: Vec<f64>
}

#[repr(C)]
struct GroupedI64F64F64 {
    groups: i64,
    keys: Vec<i64>,
    sums0: Vec<f64>,
    sums1: Vec<f64>,
    counts: Vec<i64>
}

#[repr(C)]
struct GroupedStrF64 {
    groups: i64,
    keys: Vec<str>,
    sums: Vec<f64>,
    counts: Vec<i64>
}

#[repr(C)]
struct ValueCountsStr {
    groups: i64,
    keys: Vec<str>,
    counts: Vec<i64>
}

#[repr(C)]
struct ValueCountsI64 {
    groups: i64,
    keys: Vec<i64>,
    counts: Vec<i64>
}

#[repr(C)]
struct JoinedStrF64F64 {
    rows: i64,
    keys: Vec<str>,
    left_values: Vec<f64>,
    right_values: Vec<f64>
}

#[repr(C)]
struct LeftJoinedStrF64F64 {
    rows: i64,
    keys: Vec<str>,
    left_values: Vec<f64>,
    right_valid: Vec<i64>,
    right_values: Vec<f64>
}

#[repr(C)]
struct RightJoinedStrF64F64 {
    rows: i64,
    keys: Vec<str>,
    left_valid: Vec<i64>,
    left_values: Vec<f64>,
    right_values: Vec<f64>
}

#[repr(C)]
struct OuterJoinedStrF64F64 {
    rows: i64,
    keys: Vec<str>,
    left_valid: Vec<i64>,
    left_values: Vec<f64>,
    right_valid: Vec<i64>,
    right_values: Vec<f64>
}

#[repr(C)]
struct JoinedI64F64F64 {
    rows: i64,
    keys: Vec<i64>,
    left_values: Vec<f64>,
    right_values: Vec<f64>
}

#[repr(C)]
struct LeftJoinedI64F64F64 {
    rows: i64,
    keys: Vec<i64>,
    left_values: Vec<f64>,
    right_valid: Vec<i64>,
    right_values: Vec<f64>
}

#[repr(C)]
struct RightJoinedI64F64F64 {
    rows: i64,
    keys: Vec<i64>,
    left_valid: Vec<i64>,
    left_values: Vec<f64>,
    right_values: Vec<f64>
}

#[repr(C)]
struct OuterJoinedI64F64F64 {
    rows: i64,
    keys: Vec<i64>,
    left_valid: Vec<i64>,
    left_values: Vec<f64>,
    right_valid: Vec<i64>,
    right_values: Vec<f64>
}

#[repr(C)]
struct DescribeF64 {
    count: i64,
    mean: f64,
    min: f64,
    max: f64
}

#[manual_drop]
fn frame_i64_f64_from_vec(key_name: str, value_name: str, keys: Vec<i64>, values: Vec<f64>) -> FrameI64F64 {
    return FrameI64F64 {
        key_name: key_name,
        value_name: value_name,
        rows: vec_len(keys),
        keys: keys,
        values: values
    };
}

#[manual_drop]
fn frame_i64_nullable_f64_from_vec(
    key_name: str,
    value_name: str,
    keys: Vec<i64>,
    values: Vec<f64>,
    valid: Vec<i64>
) -> FrameI64NullableF64 {
    return FrameI64NullableF64 {
        key_name: key_name,
        value_name: value_name,
        rows: vec_len(keys),
        keys: keys,
        values: values,
        valid: valid
    };
}

#[manual_drop]
fn frame_str_f64_from_vec(key_name: str, value_name: str, keys: Vec<str>, values: Vec<f64>) -> FrameStrF64 {
    return FrameStrF64 {
        key_name: key_name,
        value_name: value_name,
        rows: vec_len(keys),
        keys: keys,
        values: values
    };
}

#[manual_drop]
fn frame_str_nullable_f64_from_vec(
    key_name: str,
    value_name: str,
    keys: Vec<str>,
    values: Vec<f64>,
    valid: Vec<i64>
) -> FrameStrNullableF64 {
    return FrameStrNullableF64 {
        key_name: key_name,
        value_name: value_name,
        rows: vec_len(keys),
        keys: keys,
        values: values,
        valid: valid
    };
}

#[manual_drop]
fn frame_i64_f64_f64_from_vec(
    key_name: str,
    value0_name: str,
    value1_name: str,
    keys: Vec<i64>,
    values0: Vec<f64>,
    values1: Vec<f64>
) -> FrameI64F64F64 {
    return FrameI64F64F64 {
        key_name: key_name,
        value0_name: value0_name,
        value1_name: value1_name,
        rows: vec_len(keys),
        keys: keys,
        values0: values0,
        values1: values1
    };
}

fn frame_i64_f64_from_csv_i64_text(raw: str, key_name: str, value_name: str, has_header: i64) -> FrameI64F64 {
    let lines: Vec<str> = str_lines(raw);
    let mut keys: Vec<i64> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut line_idx: i64 = 0;
    if has_header == 1 { line_idx = 1; };

    while line_idx < vec_len(lines) {
        let line: str = str_trim(vec_get(lines, line_idx));
        if str_len(line) > 0 {
            let cells: Vec<str> = str_split(line, ",");
            if vec_len(cells) >= 2 {
                keys.push(str_to_i64(str_trim(vec_get(cells, 0))));
                values.push(str_to_i64(str_trim(vec_get(cells, 1))) as f64);
            };
        };
        line_idx = line_idx + 1;
    };

    return frame_i64_f64_from_vec(key_name, value_name, keys, values);
}

fn frame_i64_f64_from_csv_f64_text(raw: str, key_name: str, value_name: str, has_header: i64) -> FrameI64F64 {
    let lines: Vec<str> = str_lines(raw);
    let mut keys: Vec<i64> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut line_idx: i64 = 0;
    if has_header == 1 { line_idx = 1; };

    while line_idx < vec_len(lines) {
        let line: str = str_trim(vec_get(lines, line_idx));
        if str_len(line) > 0 {
            let cells: Vec<str> = str_split(line, ",");
            if vec_len(cells) >= 2 {
                keys.push(str_to_i64(str_trim(vec_get(cells, 0))));
                values.push(parse_f64_decimal(str_trim(vec_get(cells, 1))));
            };
        };
        line_idx = line_idx + 1;
    };

    return frame_i64_f64_from_vec(key_name, value_name, keys, values);
}

fn data_i64_f64_is_missing_cell(cell: str) -> i64 {
    let trimmed: str = str_trim(cell);
    if str_len(trimmed) == 0 { return 1; };
    if str_eq(trimmed, "NA") { return 1; };
    if str_eq(trimmed, "NaN") { return 1; };
    if str_eq(trimmed, "null") { return 1; };
    return 0;
}

fn frame_i64_nullable_f64_from_csv_i64_text(raw: str, key_name: str, value_name: str, has_header: i64) -> FrameI64NullableF64 {
    let lines: Vec<str> = str_lines(raw);
    let mut keys: Vec<i64> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut valid: Vec<i64> = Vec::new();
    let mut line_idx: i64 = 0;
    if has_header == 1 { line_idx = 1; };

    while line_idx < vec_len(lines) {
        let line: str = str_trim(vec_get(lines, line_idx));
        if str_len(line) > 0 {
            let cells: Vec<str> = str_split(line, ",");
            if vec_len(cells) >= 2 {
                let value_cell: str = str_trim(vec_get(cells, 1));
                keys.push(str_to_i64(str_trim(vec_get(cells, 0))));
                if data_i64_f64_is_missing_cell(value_cell) == 1 {
                    values.push(0.0);
                    valid.push(0);
                } else {
                    values.push(parse_f64_decimal(value_cell));
                    valid.push(1);
                };
            };
        };
        line_idx = line_idx + 1;
    };

    return frame_i64_nullable_f64_from_vec(key_name, value_name, keys, values, valid);
}

fn frame_str_f64_from_csv_f64_text(raw: str, key_name: str, value_name: str, has_header: i64) -> FrameStrF64 {
    let lines: Vec<str> = str_lines(raw);
    let mut keys: Vec<str> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut line_idx: i64 = 0;
    if has_header == 1 { line_idx = 1; };

    while line_idx < vec_len(lines) {
        let line: str = str_trim(vec_get(lines, line_idx));
        if str_len(line) > 0 {
            let cells: Vec<str> = str_split(line, ",");
            if vec_len(cells) >= 2 {
                keys.push(str_trim(vec_get(cells, 0)));
                values.push(parse_f64_decimal(str_trim(vec_get(cells, 1))));
            };
        };
        line_idx = line_idx + 1;
    };

    return frame_str_f64_from_vec(key_name, value_name, keys, values);
}

fn frame_str_nullable_f64_from_csv_f64_text(raw: str, key_name: str, value_name: str, has_header: i64) -> FrameStrNullableF64 {
    let lines: Vec<str> = str_lines(raw);
    let mut keys: Vec<str> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut valid: Vec<i64> = Vec::new();
    let mut line_idx: i64 = 0;
    if has_header == 1 { line_idx = 1; };

    while line_idx < vec_len(lines) {
        let line: str = str_trim(vec_get(lines, line_idx));
        if str_len(line) > 0 {
            let cells: Vec<str> = str_split(line, ",");
            if vec_len(cells) >= 2 {
                let value_cell: str = str_trim(vec_get(cells, 1));
                keys.push(str_trim(vec_get(cells, 0)));
                if data_i64_f64_is_missing_cell(value_cell) == 1 {
                    values.push(0.0);
                    valid.push(0);
                } else {
                    values.push(parse_f64_decimal(value_cell));
                    valid.push(1);
                };
            };
        };
        line_idx = line_idx + 1;
    };

    return frame_str_nullable_f64_from_vec(key_name, value_name, keys, values, valid);
}

fn frame_i64_f64_f64_from_csv_f64_text(
    raw: str,
    key_name: str,
    value0_name: str,
    value1_name: str,
    has_header: i64
) -> FrameI64F64F64 {
    let lines: Vec<str> = str_lines(raw);
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut line_idx: i64 = 0;
    if has_header == 1 { line_idx = 1; };

    while line_idx < vec_len(lines) {
        let line: str = str_trim(vec_get(lines, line_idx));
        if str_len(line) > 0 {
            let cells: Vec<str> = str_split(line, ",");
            if vec_len(cells) >= 3 {
                keys.push(str_to_i64(str_trim(vec_get(cells, 0))));
                values0.push(parse_f64_decimal(str_trim(vec_get(cells, 1))));
                values1.push(parse_f64_decimal(str_trim(vec_get(cells, 2))));
            };
        };
        line_idx = line_idx + 1;
    };

    return frame_i64_f64_f64_from_vec(key_name, value0_name, value1_name, keys, values0, values1);
}

fn frame_i64_f64_from_csv_i64(path: str, key_name: str, value_name: str, has_header: i64) -> FrameI64F64 {
    let raw: str = file_read_string(path);
    return frame_i64_f64_from_csv_i64_text(raw, key_name, value_name, has_header);
}

fn frame_i64_f64_from_csv_f64(path: str, key_name: str, value_name: str, has_header: i64) -> FrameI64F64 {
    let raw: str = file_read_string(path);
    return frame_i64_f64_from_csv_f64_text(raw, key_name, value_name, has_header);
}

fn frame_i64_nullable_f64_from_csv_i64(path: str, key_name: str, value_name: str, has_header: i64) -> FrameI64NullableF64 {
    let raw: str = file_read_string(path);
    return frame_i64_nullable_f64_from_csv_i64_text(raw, key_name, value_name, has_header);
}

fn frame_str_f64_from_csv_f64(path: str, key_name: str, value_name: str, has_header: i64) -> FrameStrF64 {
    let raw: str = file_read_string(path);
    return frame_str_f64_from_csv_f64_text(raw, key_name, value_name, has_header);
}

fn frame_str_nullable_f64_from_csv_f64(path: str, key_name: str, value_name: str, has_header: i64) -> FrameStrNullableF64 {
    let raw: str = file_read_string(path);
    return frame_str_nullable_f64_from_csv_f64_text(raw, key_name, value_name, has_header);
}

fn frame_i64_f64_f64_from_csv_f64(
    path: str,
    key_name: str,
    value0_name: str,
    value1_name: str,
    has_header: i64
) -> FrameI64F64F64 {
    let raw: str = file_read_string(path);
    return frame_i64_f64_f64_from_csv_f64_text(raw, key_name, value0_name, value1_name, has_header);
}

fn grouped_i64_f64_find_key(grouped: &GroupedI64F64, key: i64) -> i64 {
    let mut i: i64 = 0;
    while i < grouped.groups {
        if grouped.keys[i] == key { return i; };
        i = i + 1;
    };
    return -1;
}

fn grouped_stats_i64_f64_find_key(grouped: &GroupedStatsI64F64, key: i64) -> i64 {
    let mut i: i64 = 0;
    while i < grouped.groups {
        if grouped.keys[i] == key { return i; };
        i = i + 1;
    };
    return -1;
}

fn grouped_i64_f64_f64_find_key(grouped: &GroupedI64F64F64, key: i64) -> i64 {
    let mut i: i64 = 0;
    while i < grouped.groups {
        if grouped.keys[i] == key { return i; };
        i = i + 1;
    };
    return -1;
}

fn grouped_str_f64_find_key(grouped: &GroupedStrF64, key: str) -> i64 {
    let mut i: i64 = 0;
    while i < grouped.groups {
        if str_eq(vec_get(grouped.keys, i), key) { return i; };
        i = i + 1;
    };
    return -1;
}

fn value_counts_str_find_key(counts: &ValueCountsStr, key: str) -> i64 {
    let mut i: i64 = 0;
    while i < counts.groups {
        if str_eq(vec_get(counts.keys, i), key) { return i; };
        i = i + 1;
    };
    return -1;
}

fn value_counts_i64_find_key(counts: &ValueCountsI64, key: i64) -> i64 {
    let mut i: i64 = 0;
    while i < counts.groups {
        if counts.keys[i] == key { return i; };
        i = i + 1;
    };
    return -1;
}

fn frame_i64_f64_groupby_sum_mean(frame: &FrameI64F64) -> GroupedI64F64 {
    let mut gkeys: Vec<i64> = Vec::new();
    let mut sums: Vec<f64> = Vec::new();
    let mut counts: Vec<i64> = Vec::new();
    let mut grouped: GroupedI64F64 = GroupedI64F64 {
        groups: 0,
        keys: gkeys,
        sums: sums,
        counts: counts
    };

    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let existing: i64 = grouped_i64_f64_find_key(&grouped, key);
        if existing < 0 {
            grouped.keys.push(key);
            grouped.sums.push(value);
            grouped.counts.push(1);
            grouped.groups = grouped.groups + 1;
        } else {
            vec_set(grouped.sums, existing, grouped.sums[existing] + value);
            vec_set(grouped.counts, existing, grouped.counts[existing] + 1);
        };
        i = i + 1;
    };
    return grouped;
}

fn frame_i64_f64_groupby_count_min_max(frame: &FrameI64F64) -> GroupedStatsI64F64 {
    let mut gkeys: Vec<i64> = Vec::new();
    let mut counts: Vec<i64> = Vec::new();
    let mut mins: Vec<f64> = Vec::new();
    let mut maxs: Vec<f64> = Vec::new();
    let mut grouped: GroupedStatsI64F64 = GroupedStatsI64F64 {
        groups: 0,
        keys: gkeys,
        counts: counts,
        mins: mins,
        maxs: maxs
    };

    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let existing: i64 = grouped_stats_i64_f64_find_key(&grouped, key);
        if existing < 0 {
            grouped.keys.push(key);
            grouped.counts.push(1);
            grouped.mins.push(value);
            grouped.maxs.push(value);
            grouped.groups = grouped.groups + 1;
        } else {
            vec_set(grouped.counts, existing, grouped.counts[existing] + 1);
            if value < grouped.mins[existing] {
                vec_set(grouped.mins, existing, value);
            };
            if value > grouped.maxs[existing] {
                vec_set(grouped.maxs, existing, value);
            };
        };
        i = i + 1;
    };
    return grouped;
}

fn frame_i64_f64_f64_groupby_sum_mean(frame: &FrameI64F64F64) -> GroupedI64F64F64 {
    let mut gkeys: Vec<i64> = Vec::new();
    let mut sums0: Vec<f64> = Vec::new();
    let mut sums1: Vec<f64> = Vec::new();
    let mut counts: Vec<i64> = Vec::new();
    let mut grouped: GroupedI64F64F64 = GroupedI64F64F64 {
        groups: 0,
        keys: gkeys,
        sums0: sums0,
        sums1: sums1,
        counts: counts
    };

    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value0: f64 = frame.values0[i];
        let value1: f64 = frame.values1[i];
        let existing: i64 = grouped_i64_f64_f64_find_key(&grouped, key);
        if existing < 0 {
            grouped.keys.push(key);
            grouped.sums0.push(value0);
            grouped.sums1.push(value1);
            grouped.counts.push(1);
            grouped.groups = grouped.groups + 1;
        } else {
            vec_set(grouped.sums0, existing, grouped.sums0[existing] + value0);
            vec_set(grouped.sums1, existing, grouped.sums1[existing] + value1);
            vec_set(grouped.counts, existing, grouped.counts[existing] + 1);
        };
        i = i + 1;
    };
    return grouped;
}

fn frame_str_f64_groupby_sum_mean(frame: &FrameStrF64) -> GroupedStrF64 {
    let mut gkeys: Vec<str> = Vec::new();
    let mut sums: Vec<f64> = Vec::new();
    let mut counts: Vec<i64> = Vec::new();
    let mut grouped: GroupedStrF64 = GroupedStrF64 {
        groups: 0,
        keys: gkeys,
        sums: sums,
        counts: counts
    };

    let mut i: i64 = 0;
    while i < frame.rows {
        let key: str = vec_get(frame.keys, i);
        let value: f64 = frame.values[i];
        let existing: i64 = grouped_str_f64_find_key(&grouped, key);
        if existing < 0 {
            grouped.keys.push(key);
            grouped.sums.push(value);
            grouped.counts.push(1);
            grouped.groups = grouped.groups + 1;
        } else {
            vec_set(grouped.sums, existing, grouped.sums[existing] + value);
            vec_set(grouped.counts, existing, grouped.counts[existing] + 1);
        };
        i = i + 1;
    };
    return grouped;
}

fn frame_str_f64_value_counts_by_key(frame: &FrameStrF64) -> ValueCountsStr {
    let mut keys: Vec<str> = Vec::new();
    let mut count_values: Vec<i64> = Vec::new();
    let mut counts: ValueCountsStr = ValueCountsStr {
        groups: 0,
        keys: keys,
        counts: count_values
    };

    let mut i: i64 = 0;
    while i < frame.rows {
        let key: str = vec_get(frame.keys, i);
        let existing: i64 = value_counts_str_find_key(&counts, key);
        if existing < 0 {
            counts.keys.push(key);
            counts.counts.push(1);
            counts.groups = counts.groups + 1;
        } else {
            vec_set(counts.counts, existing, counts.counts[existing] + 1);
        };
        i = i + 1;
    };
    return counts;
}

fn frame_i64_f64_value_counts_by_key(frame: &FrameI64F64) -> ValueCountsI64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut count_values: Vec<i64> = Vec::new();
    let mut counts: ValueCountsI64 = ValueCountsI64 {
        groups: 0,
        keys: keys,
        counts: count_values
    };

    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let existing: i64 = value_counts_i64_find_key(&counts, key);
        if existing < 0 {
            counts.keys.push(key);
            counts.counts.push(1);
            counts.groups = counts.groups + 1;
        } else {
            vec_set(counts.counts, existing, counts.counts[existing] + 1);
        };
        i = i + 1;
    };
    return counts;
}

fn frame_str_f64_drop_duplicates_by_key_keep_first(frame: &FrameStrF64) -> FrameStrF64 {
    let mut keys: Vec<str> = Vec::new();
    let mut values: Vec<f64> = Vec::new();

    let mut i: i64 = 0;
    while i < frame.rows {
        let key: str = vec_get(frame.keys, i);
        let mut seen: i64 = 0;
        let mut j: i64 = 0;
        while j < i {
            if str_eq(vec_get(frame.keys, j), key) {
                seen = 1;
            };
            j = j + 1;
        };
        if seen == 0 {
            keys.push(key);
            values.push(frame.values[i]);
        };
        i = i + 1;
    };

    return frame_str_f64_from_vec(frame.key_name, frame.value_name, keys, values);
}

fn frame_str_f64_sort_by_key_asc(frame: &FrameStrF64) -> FrameStrF64 {
    let mut keys: Vec<str> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        keys.push(vec_get(frame.keys, i));
        values.push(frame.values[i]);
        i = i + 1;
    };

    i = 1;
    while i < frame.rows {
        let key: str = vec_get(keys, i);
        let value: f64 = values[i];
        let mut j: i64 = i - 1;
        while j >= 0 && data_str_cmp(vec_get(keys, j), key) > 0 {
            vec_set(keys, j + 1, vec_get(keys, j));
            vec_set(values, j + 1, values[j]);
            j = j - 1;
        };
        vec_set(keys, j + 1, key);
        vec_set(values, j + 1, value);
        i = i + 1;
    };

    return frame_str_f64_from_vec(frame.key_name, frame.value_name, keys, values);
}

fn frame_str_f64_describe_value(frame: &FrameStrF64) -> DescribeF64 {
    if frame.rows == 0 {
        return DescribeF64 { count: 0, mean: 0.0, min: 0.0, max: 0.0 };
    };

    let mut sum: f64 = 0.0;
    let mut min_value: f64 = frame.values[0];
    let mut max_value: f64 = frame.values[0];
    let mut i: i64 = 0;
    while i < frame.rows {
        let value: f64 = frame.values[i];
        sum = sum + value;
        if value < min_value { min_value = value; };
        if value > max_value { max_value = value; };
        i = i + 1;
    };

    return DescribeF64 {
        count: frame.rows,
        mean: sum / (frame.rows as f64),
        min: min_value,
        max: max_value
    };
}

fn frame_str_f64_filter_value_ge(frame: &FrameStrF64, minimum: f64) -> FrameStrF64 {
    let mut keys: Vec<str> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        if frame.values[i] >= minimum {
            keys.push(vec_get(frame.keys, i));
            values.push(frame.values[i]);
        };
        i = i + 1;
    };
    return frame_str_f64_from_vec(frame.key_name, frame.value_name, keys, values);
}

fn frame_str_f64_inner_join(left: &FrameStrF64, right: &FrameStrF64) -> JoinedStrF64F64 {
    let mut keys: Vec<str> = Vec::new();
    let mut left_values: Vec<f64> = Vec::new();
    let mut right_values: Vec<f64> = Vec::new();
    let mut rows: i64 = 0;

    let mut li: i64 = 0;
    while li < left.rows {
        let left_key: str = vec_get(left.keys, li);
        let mut ri: i64 = 0;
        while ri < right.rows {
            if str_eq(left_key, vec_get(right.keys, ri)) {
                keys.push(left_key);
                left_values.push(left.values[li]);
                right_values.push(right.values[ri]);
                rows = rows + 1;
            };
            ri = ri + 1;
        };
        li = li + 1;
    };

    return JoinedStrF64F64 {
        rows: rows,
        keys: keys,
        left_values: left_values,
        right_values: right_values
    };
}

fn frame_str_f64_left_join(left: &FrameStrF64, right: &FrameStrF64) -> LeftJoinedStrF64F64 {
    let mut keys: Vec<str> = Vec::new();
    let mut left_values: Vec<f64> = Vec::new();
    let mut right_valid: Vec<i64> = Vec::new();
    let mut right_values: Vec<f64> = Vec::new();
    let mut rows: i64 = 0;

    let mut li: i64 = 0;
    while li < left.rows {
        let left_key: str = vec_get(left.keys, li);
        let mut matched: i64 = 0;
        let mut ri: i64 = 0;
        while ri < right.rows {
            if str_eq(left_key, vec_get(right.keys, ri)) {
                keys.push(left_key);
                left_values.push(left.values[li]);
                right_valid.push(1);
                right_values.push(right.values[ri]);
                rows = rows + 1;
                matched = 1;
            };
            ri = ri + 1;
        };
        if matched == 0 {
            keys.push(left_key);
            left_values.push(left.values[li]);
            right_valid.push(0);
            right_values.push(0.0);
            rows = rows + 1;
        };
        li = li + 1;
    };

    return LeftJoinedStrF64F64 {
        rows: rows,
        keys: keys,
        left_values: left_values,
        right_valid: right_valid,
        right_values: right_values
    };
}

fn frame_str_f64_right_join(left: &FrameStrF64, right: &FrameStrF64) -> RightJoinedStrF64F64 {
    let mut keys: Vec<str> = Vec::new();
    let mut left_valid: Vec<i64> = Vec::new();
    let mut left_values: Vec<f64> = Vec::new();
    let mut right_values: Vec<f64> = Vec::new();
    let mut rows: i64 = 0;

    let mut ri: i64 = 0;
    while ri < right.rows {
        let right_key: str = vec_get(right.keys, ri);
        let mut matched: i64 = 0;
        let mut li: i64 = 0;
        while li < left.rows {
            if str_eq(vec_get(left.keys, li), right_key) {
                keys.push(right_key);
                left_valid.push(1);
                left_values.push(left.values[li]);
                right_values.push(right.values[ri]);
                rows = rows + 1;
                matched = 1;
            };
            li = li + 1;
        };
        if matched == 0 {
            keys.push(right_key);
            left_valid.push(0);
            left_values.push(0.0);
            right_values.push(right.values[ri]);
            rows = rows + 1;
        };
        ri = ri + 1;
    };

    return RightJoinedStrF64F64 {
        rows: rows,
        keys: keys,
        left_valid: left_valid,
        left_values: left_values,
        right_values: right_values
    };
}

fn data_str_cmp(a: str, b: str) -> i64 {
    let alen: i64 = str_len(a);
    let blen: i64 = str_len(b);
    let mut limit: i64 = alen;
    if blen < limit { limit = blen; };

    let mut i: i64 = 0;
    while i < limit {
        let ca: i64 = str_char_at(a, i);
        let cb: i64 = str_char_at(b, i);
        if ca < cb { return -1; };
        if ca > cb { return 1; };
        i = i + 1;
    };
    if alen < blen { return -1; };
    if alen > blen { return 1; };
    return 0;
}

fn frame_str_f64_outer_join(left: &FrameStrF64, right: &FrameStrF64) -> OuterJoinedStrF64F64 {
    let mut union_keys: Vec<str> = Vec::new();

    let mut li0: i64 = 0;
    while li0 < left.rows {
        let left_key0: str = vec_get(left.keys, li0);
        let mut seen_left0: i64 = 0;
        let mut ki0: i64 = 0;
        while ki0 < vec_len(union_keys) {
            if str_eq(vec_get(union_keys, ki0), left_key0) {
                seen_left0 = 1;
            };
            ki0 = ki0 + 1;
        };
        if seen_left0 == 0 {
            union_keys.push(left_key0);
        };
        li0 = li0 + 1;
    };

    let mut ri0: i64 = 0;
    while ri0 < right.rows {
        let right_key0: str = vec_get(right.keys, ri0);
        let mut seen_right0: i64 = 0;
        let mut ki1: i64 = 0;
        while ki1 < vec_len(union_keys) {
            if str_eq(vec_get(union_keys, ki1), right_key0) {
                seen_right0 = 1;
            };
            ki1 = ki1 + 1;
        };
        if seen_right0 == 0 {
            union_keys.push(right_key0);
        };
        ri0 = ri0 + 1;
    };

    let mut si: i64 = 1;
    while si < vec_len(union_keys) {
        let sort_key: str = vec_get(union_keys, si);
        let mut sj: i64 = si - 1;
        while sj >= 0 && data_str_cmp(vec_get(union_keys, sj), sort_key) > 0 {
            vec_set(union_keys, sj + 1, vec_get(union_keys, sj));
            sj = sj - 1;
        };
        vec_set(union_keys, sj + 1, sort_key);
        si = si + 1;
    };

    let mut keys: Vec<str> = Vec::new();
    let mut left_valid: Vec<i64> = Vec::new();
    let mut left_values: Vec<f64> = Vec::new();
    let mut right_valid: Vec<i64> = Vec::new();
    let mut right_values: Vec<f64> = Vec::new();
    let mut rows: i64 = 0;

    let mut ki: i64 = 0;
    while ki < vec_len(union_keys) {
        let key: str = vec_get(union_keys, ki);
        let mut left_seen: i64 = 0;
        let mut right_seen: i64 = 0;

        let mut li_seen: i64 = 0;
        while li_seen < left.rows {
            if str_eq(vec_get(left.keys, li_seen), key) {
                left_seen = 1;
            };
            li_seen = li_seen + 1;
        };

        let mut ri_seen: i64 = 0;
        while ri_seen < right.rows {
            if str_eq(vec_get(right.keys, ri_seen), key) {
                right_seen = 1;
            };
            ri_seen = ri_seen + 1;
        };

        if left_seen == 1 {
            if right_seen == 1 {
                let mut li: i64 = 0;
                while li < left.rows {
                    if str_eq(vec_get(left.keys, li), key) {
                        let mut ri: i64 = 0;
                        while ri < right.rows {
                            if str_eq(vec_get(right.keys, ri), key) {
                                keys.push(key);
                                left_valid.push(1);
                                left_values.push(left.values[li]);
                                right_valid.push(1);
                                right_values.push(right.values[ri]);
                                rows = rows + 1;
                            };
                            ri = ri + 1;
                        };
                    };
                    li = li + 1;
                };
            } else {
                let mut li_only: i64 = 0;
                while li_only < left.rows {
                    if str_eq(vec_get(left.keys, li_only), key) {
                        keys.push(key);
                        left_valid.push(1);
                        left_values.push(left.values[li_only]);
                        right_valid.push(0);
                        right_values.push(0.0);
                        rows = rows + 1;
                    };
                    li_only = li_only + 1;
                };
            };
        } else {
            if right_seen == 1 {
                let mut ri_only: i64 = 0;
                while ri_only < right.rows {
                    if str_eq(vec_get(right.keys, ri_only), key) {
                        keys.push(key);
                        left_valid.push(0);
                        left_values.push(0.0);
                        right_valid.push(1);
                        right_values.push(right.values[ri_only]);
                        rows = rows + 1;
                    };
                    ri_only = ri_only + 1;
                };
            };
        };

        ki = ki + 1;
    };

    return OuterJoinedStrF64F64 {
        rows: rows,
        keys: keys,
        left_valid: left_valid,
        left_values: left_values,
        right_valid: right_valid,
        right_values: right_values
    };
}

fn frame_i64_f64_sort_by_key_asc(frame: &FrameI64F64) -> FrameI64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        keys.push(frame.keys[i]);
        values.push(frame.values[i]);
        i = i + 1;
    };

    i = 1;
    while i < frame.rows {
        let key: i64 = keys[i];
        let value: f64 = values[i];
        let mut j: i64 = i - 1;
        while j >= 0 && keys[j] > key {
            vec_set(keys, j + 1, keys[j]);
            vec_set(values, j + 1, values[j]);
            j = j - 1;
        };
        vec_set(keys, j + 1, key);
        vec_set(values, j + 1, value);
        i = i + 1;
    };

    return frame_i64_f64_from_vec(frame.key_name, frame.value_name, keys, values);
}

fn frame_i64_f64_f64_sort_by_key_asc(frame: &FrameI64F64F64) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        keys.push(frame.keys[i]);
        values0.push(frame.values0[i]);
        values1.push(frame.values1[i]);
        i = i + 1;
    };

    i = 1;
    while i < frame.rows {
        let key: i64 = keys[i];
        let value0: f64 = values0[i];
        let value1: f64 = values1[i];
        let mut j: i64 = i - 1;
        while j >= 0 && keys[j] > key {
            vec_set(keys, j + 1, keys[j]);
            vec_set(values0, j + 1, values0[j]);
            vec_set(values1, j + 1, values1[j]);
            j = j - 1;
        };
        vec_set(keys, j + 1, key);
        vec_set(values0, j + 1, value0);
        vec_set(values1, j + 1, value1);
        i = i + 1;
    };

    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value0_name, frame.value1_name, keys, values0, values1);
}

fn frame_i64_f64_drop_duplicates_by_key_keep_first(frame: &FrameI64F64) -> FrameI64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values: Vec<f64> = Vec::new();

    let mut i: i64 = 0;
    while i < frame.rows {
        let mut seen: i64 = 0;
        let mut j: i64 = 0;
        while j < i {
            if frame.keys[j] == frame.keys[i] {
                seen = 1;
            };
            j = j + 1;
        };
        if seen == 0 {
            keys.push(frame.keys[i]);
            values.push(frame.values[i]);
        };
        i = i + 1;
    };

    return frame_i64_f64_from_vec(frame.key_name, frame.value_name, keys, values);
}

fn frame_i64_f64_f64_drop_duplicates_by_key_keep_first(frame: &FrameI64F64F64) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();

    let mut i: i64 = 0;
    while i < frame.rows {
        let mut seen: i64 = 0;
        let mut j: i64 = 0;
        while j < i {
            if frame.keys[j] == frame.keys[i] {
                seen = 1;
            };
            j = j + 1;
        };
        if seen == 0 {
            keys.push(frame.keys[i]);
            values0.push(frame.values0[i]);
            values1.push(frame.values1[i]);
        };
        i = i + 1;
    };

    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value0_name, frame.value1_name, keys, values0, values1);
}

fn frame_i64_f64_describe_value(frame: &FrameI64F64) -> DescribeF64 {
    if frame.rows == 0 {
        return DescribeF64 { count: 0, mean: 0.0, min: 0.0, max: 0.0 };
    };

    let mut sum: f64 = 0.0;
    let mut min_value: f64 = frame.values[0];
    let mut max_value: f64 = frame.values[0];
    let mut i: i64 = 0;
    while i < frame.rows {
        let value: f64 = frame.values[i];
        sum = sum + value;
        if value < min_value { min_value = value; };
        if value > max_value { max_value = value; };
        i = i + 1;
    };

    return DescribeF64 {
        count: frame.rows,
        mean: sum / (frame.rows as f64),
        min: min_value,
        max: max_value
    };
}

fn frame_i64_f64_f64_describe_value0(frame: &FrameI64F64F64) -> DescribeF64 {
    if frame.rows == 0 {
        return DescribeF64 { count: 0, mean: 0.0, min: 0.0, max: 0.0 };
    };

    let mut sum: f64 = 0.0;
    let mut min_value: f64 = frame.values0[0];
    let mut max_value: f64 = frame.values0[0];
    let mut i: i64 = 0;
    while i < frame.rows {
        let value: f64 = frame.values0[i];
        sum = sum + value;
        if value < min_value { min_value = value; };
        if value > max_value { max_value = value; };
        i = i + 1;
    };

    return DescribeF64 {
        count: frame.rows,
        mean: sum / (frame.rows as f64),
        min: min_value,
        max: max_value
    };
}

fn frame_i64_f64_f64_describe_value1(frame: &FrameI64F64F64) -> DescribeF64 {
    if frame.rows == 0 {
        return DescribeF64 { count: 0, mean: 0.0, min: 0.0, max: 0.0 };
    };

    let mut sum: f64 = 0.0;
    let mut min_value: f64 = frame.values1[0];
    let mut max_value: f64 = frame.values1[0];
    let mut i: i64 = 0;
    while i < frame.rows {
        let value: f64 = frame.values1[i];
        sum = sum + value;
        if value < min_value { min_value = value; };
        if value > max_value { max_value = value; };
        i = i + 1;
    };

    return DescribeF64 {
        count: frame.rows,
        mean: sum / (frame.rows as f64),
        min: min_value,
        max: max_value
    };
}

fn frame_i64_f64_inner_join(left: &FrameI64F64, right: &FrameI64F64) -> JoinedI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut left_values: Vec<f64> = Vec::new();
    let mut right_values: Vec<f64> = Vec::new();
    let mut rows: i64 = 0;

    let mut li: i64 = 0;
    while li < left.rows {
        let mut ri: i64 = 0;
        while ri < right.rows {
            if left.keys[li] == right.keys[ri] {
                keys.push(left.keys[li]);
                left_values.push(left.values[li]);
                right_values.push(right.values[ri]);
                rows = rows + 1;
            };
            ri = ri + 1;
        };
        li = li + 1;
    };

    return JoinedI64F64F64 {
        rows: rows,
        keys: keys,
        left_values: left_values,
        right_values: right_values
    };
}

fn frame_i64_f64_left_join(left: &FrameI64F64, right: &FrameI64F64) -> LeftJoinedI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut left_values: Vec<f64> = Vec::new();
    let mut right_valid: Vec<i64> = Vec::new();
    let mut right_values: Vec<f64> = Vec::new();
    let mut rows: i64 = 0;

    let mut li: i64 = 0;
    while li < left.rows {
        let mut matched: i64 = 0;
        let mut ri: i64 = 0;
        while ri < right.rows {
            if left.keys[li] == right.keys[ri] {
                keys.push(left.keys[li]);
                left_values.push(left.values[li]);
                right_valid.push(1);
                right_values.push(right.values[ri]);
                rows = rows + 1;
                matched = 1;
            };
            ri = ri + 1;
        };
        if matched == 0 {
            keys.push(left.keys[li]);
            left_values.push(left.values[li]);
            right_valid.push(0);
            right_values.push(0.0);
            rows = rows + 1;
        };
        li = li + 1;
    };

    return LeftJoinedI64F64F64 {
        rows: rows,
        keys: keys,
        left_values: left_values,
        right_valid: right_valid,
        right_values: right_values
    };
}

fn frame_i64_f64_right_join(left: &FrameI64F64, right: &FrameI64F64) -> RightJoinedI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut left_valid: Vec<i64> = Vec::new();
    let mut left_values: Vec<f64> = Vec::new();
    let mut right_values: Vec<f64> = Vec::new();
    let mut rows: i64 = 0;

    let mut ri: i64 = 0;
    while ri < right.rows {
        let mut matched: i64 = 0;
        let mut li: i64 = 0;
        while li < left.rows {
            if left.keys[li] == right.keys[ri] {
                keys.push(right.keys[ri]);
                left_valid.push(1);
                left_values.push(left.values[li]);
                right_values.push(right.values[ri]);
                rows = rows + 1;
                matched = 1;
            };
            li = li + 1;
        };
        if matched == 0 {
            keys.push(right.keys[ri]);
            left_valid.push(0);
            left_values.push(0.0);
            right_values.push(right.values[ri]);
            rows = rows + 1;
        };
        ri = ri + 1;
    };

    return RightJoinedI64F64F64 {
        rows: rows,
        keys: keys,
        left_valid: left_valid,
        left_values: left_values,
        right_values: right_values
    };
}

fn frame_i64_f64_outer_join(left: &FrameI64F64, right: &FrameI64F64) -> OuterJoinedI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut left_valid: Vec<i64> = Vec::new();
    let mut left_values: Vec<f64> = Vec::new();
    let mut right_valid: Vec<i64> = Vec::new();
    let mut right_values: Vec<f64> = Vec::new();
    let mut rows: i64 = 0;

    let mut li: i64 = 0;
    while li < left.rows {
        let mut matched: i64 = 0;
        let mut ri: i64 = 0;
        while ri < right.rows {
            if left.keys[li] == right.keys[ri] {
                keys.push(left.keys[li]);
                left_valid.push(1);
                left_values.push(left.values[li]);
                right_valid.push(1);
                right_values.push(right.values[ri]);
                rows = rows + 1;
                matched = 1;
            };
            ri = ri + 1;
        };
        if matched == 0 {
            keys.push(left.keys[li]);
            left_valid.push(1);
            left_values.push(left.values[li]);
            right_valid.push(0);
            right_values.push(0.0);
            rows = rows + 1;
        };
        li = li + 1;
    };

    let mut ri2: i64 = 0;
    while ri2 < right.rows {
        let mut seen_left: i64 = 0;
        let mut li2: i64 = 0;
        while li2 < left.rows {
            if left.keys[li2] == right.keys[ri2] {
                seen_left = 1;
            };
            li2 = li2 + 1;
        };
        if seen_left == 0 {
            keys.push(right.keys[ri2]);
            left_valid.push(0);
            left_values.push(0.0);
            right_valid.push(1);
            right_values.push(right.values[ri2]);
            rows = rows + 1;
        };
        ri2 = ri2 + 1;
    };

    return OuterJoinedI64F64F64 {
        rows: rows,
        keys: keys,
        left_valid: left_valid,
        left_values: left_values,
        right_valid: right_valid,
        right_values: right_values
    };
}

fn frame_i64_f64_filter_value_ge(frame: &FrameI64F64, minimum: f64) -> FrameI64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        if frame.values[i] >= minimum {
            keys.push(frame.keys[i]);
            values.push(frame.values[i]);
        };
        i = i + 1;
    };
    return frame_i64_f64_from_vec(frame.key_name, frame.value_name, keys, values);
}

fn frame_i64_f64_filter_value_gt(frame: &FrameI64F64, minimum: f64) -> FrameI64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        if frame.values[i] > minimum {
            keys.push(frame.keys[i]);
            values.push(frame.values[i]);
        };
        i = i + 1;
    };
    return frame_i64_f64_from_vec(frame.key_name, frame.value_name, keys, values);
}

fn frame_i64_f64_filter_value_le(frame: &FrameI64F64, maximum: f64) -> FrameI64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        if frame.values[i] <= maximum {
            keys.push(frame.keys[i]);
            values.push(frame.values[i]);
        };
        i = i + 1;
    };
    return frame_i64_f64_from_vec(frame.key_name, frame.value_name, keys, values);
}

fn frame_i64_f64_filter_value_lt(frame: &FrameI64F64, maximum: f64) -> FrameI64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        if frame.values[i] < maximum {
            keys.push(frame.keys[i]);
            values.push(frame.values[i]);
        };
        i = i + 1;
    };
    return frame_i64_f64_from_vec(frame.key_name, frame.value_name, keys, values);
}

fn frame_i64_f64_filter_value_eq(frame: &FrameI64F64, target: f64) -> FrameI64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        if frame.values[i] == target {
            keys.push(frame.keys[i]);
            values.push(frame.values[i]);
        };
        i = i + 1;
    };
    return frame_i64_f64_from_vec(frame.key_name, frame.value_name, keys, values);
}

fn frame_i64_f64_filter_value_ne(frame: &FrameI64F64, target: f64) -> FrameI64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        if frame.values[i] != target {
            keys.push(frame.keys[i]);
            values.push(frame.values[i]);
        };
        i = i + 1;
    };
    return frame_i64_f64_from_vec(frame.key_name, frame.value_name, keys, values);
}

fn frame_i64_f64_filter_key_isin(frame: &FrameI64F64, allowed: Vec<i64>) -> FrameI64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let mut keep: i64 = 0;
        let mut j: i64 = 0;
        while j < vec_len(allowed) {
            if frame.keys[i] == allowed[j] {
                keep = 1;
            };
            j = j + 1;
        };
        if keep == 1 {
            keys.push(frame.keys[i]);
            values.push(frame.values[i]);
        };
        i = i + 1;
    };
    return frame_i64_f64_from_vec(frame.key_name, frame.value_name, keys, values);
}

fn frame_i64_f64_filter_key_notin(frame: &FrameI64F64, excluded: Vec<i64>) -> FrameI64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let mut found: i64 = 0;
        let mut j: i64 = 0;
        while j < vec_len(excluded) {
            if frame.keys[i] == excluded[j] {
                found = 1;
            };
            j = j + 1;
        };
        if found == 0 {
            keys.push(frame.keys[i]);
            values.push(frame.values[i]);
        };
        i = i + 1;
    };
    return frame_i64_f64_from_vec(frame.key_name, frame.value_name, keys, values);
}

fn frame_i64_f64_filter_value_between(frame: &FrameI64F64, lower: f64, upper: f64) -> FrameI64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        if frame.values[i] >= lower && frame.values[i] <= upper {
            keys.push(frame.keys[i]);
            values.push(frame.values[i]);
        };
        i = i + 1;
    };
    return frame_i64_f64_from_vec(frame.key_name, frame.value_name, keys, values);
}

fn frame_i64_f64_assign_scaled_value(frame: &FrameI64F64, derived_name: str, scale: f64, bias: f64) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let value: f64 = frame.values[i];
        keys.push(frame.keys[i]);
        values0.push(value);
        values1.push((value * scale) + bias);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_abs_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let value: f64 = frame.values[i];
        let mut abs_value: f64 = value;
        if value < 0.0 {
            abs_value = 0.0 - value;
        };
        keys.push(frame.keys[i]);
        values0.push(value);
        values1.push(abs_value);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_squared_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let value: f64 = frame.values[i];
        keys.push(frame.keys[i]);
        values0.push(value);
        values1.push(value * value);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_minmax_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut min_value: f64 = 0.0;
    let mut max_value: f64 = 0.0;
    if frame.rows > 0 {
        min_value = frame.values[0];
        max_value = frame.values[0];
    };
    let mut i: i64 = 1;
    while i < frame.rows {
        let value: f64 = frame.values[i];
        if value < min_value { min_value = value; };
        if value > max_value { max_value = value; };
        i = i + 1;
    };
    let denom: f64 = max_value - min_value;
    i = 0;
    while i < frame.rows {
        let value: f64 = frame.values[i];
        let mut normalized: f64 = 0.0;
        if denom != 0.0 {
            normalized = (value - min_value) / denom;
        };
        keys.push(frame.keys[i]);
        values0.push(value);
        values1.push(normalized);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_centered_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut total: f64 = 0.0;
    let mut i: i64 = 0;
    while i < frame.rows {
        total = total + frame.values[i];
        i = i + 1;
    };
    let mut mean: f64 = 0.0;
    if frame.rows > 0 {
        mean = total / (frame.rows as f64);
    };
    i = 0;
    while i < frame.rows {
        let value: f64 = frame.values[i];
        keys.push(frame.keys[i]);
        values0.push(value);
        values1.push(value - mean);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_centered_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut group_sum: f64 = 0.0;
        let mut group_count: i64 = 0;
        let mut j: i64 = 0;
        while j < frame.rows {
            if frame.keys[j] == key {
                group_sum = group_sum + frame.values[j];
                group_count = group_count + 1;
            };
            j = j + 1;
        };
        let mut group_mean: f64 = 0.0;
        if group_count > 0 {
            group_mean = group_sum / (group_count as f64);
        };
        keys.push(key);
        values0.push(value);
        values1.push(value - group_mean);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_abs_deviation_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut group_sum: f64 = 0.0;
        let mut group_count: i64 = 0;
        let mut j: i64 = 0;
        while j < frame.rows {
            if frame.keys[j] == key {
                group_sum = group_sum + frame.values[j];
                group_count = group_count + 1;
            };
            j = j + 1;
        };
        let mut group_mean: f64 = 0.0;
        if group_count > 0 {
            group_mean = group_sum / (group_count as f64);
        };
        let mut deviation: f64 = value - group_mean;
        if deviation < 0.0 {
            deviation = 0.0 - deviation;
        };
        keys.push(key);
        values0.push(value);
        values1.push(deviation);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_squared_deviation_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut group_sum: f64 = 0.0;
        let mut group_count: i64 = 0;
        let mut j: i64 = 0;
        while j < frame.rows {
            if frame.keys[j] == key {
                group_sum = group_sum + frame.values[j];
                group_count = group_count + 1;
            };
            j = j + 1;
        };
        let mut group_mean: f64 = 0.0;
        if group_count > 0 {
            group_mean = group_sum / (group_count as f64);
        };
        let deviation: f64 = value - group_mean;
        keys.push(key);
        values0.push(value);
        values1.push(deviation * deviation);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_minmax_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut group_min: f64 = value;
        let mut group_max: f64 = value;
        let mut j: i64 = 0;
        while j < frame.rows {
            if frame.keys[j] == key {
                if frame.values[j] < group_min {
                    group_min = frame.values[j];
                };
                if frame.values[j] > group_max {
                    group_max = frame.values[j];
                };
            };
            j = j + 1;
        };
        let denom: f64 = group_max - group_min;
        let mut normalized: f64 = 0.0;
        if denom != 0.0 {
            normalized = (value - group_min) / denom;
        };
        keys.push(key);
        values0.push(value);
        values1.push(normalized);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_mean_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut group_sum: f64 = 0.0;
        let mut group_count: i64 = 0;
        let mut j: i64 = 0;
        while j < frame.rows {
            if frame.keys[j] == key {
                group_sum = group_sum + frame.values[j];
                group_count = group_count + 1;
            };
            j = j + 1;
        };
        let mut group_mean: f64 = 0.0;
        if group_count > 0 {
            group_mean = group_sum / (group_count as f64);
        };
        keys.push(key);
        values0.push(value);
        values1.push(group_mean);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_min_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut group_min: f64 = value;
        let mut j: i64 = 0;
        while j < frame.rows {
            if frame.keys[j] == key {
                if frame.values[j] < group_min {
                    group_min = frame.values[j];
                };
            };
            j = j + 1;
        };
        keys.push(key);
        values0.push(value);
        values1.push(group_min);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_max_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut group_max: f64 = value;
        let mut j: i64 = 0;
        while j < frame.rows {
            if frame.keys[j] == key {
                if frame.values[j] > group_max {
                    group_max = frame.values[j];
                };
            };
            j = j + 1;
        };
        keys.push(key);
        values0.push(value);
        values1.push(group_max);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_sum_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut group_sum: f64 = 0.0;
        let mut j: i64 = 0;
        while j < frame.rows {
            if frame.keys[j] == key {
                group_sum = group_sum + frame.values[j];
            };
            j = j + 1;
        };
        keys.push(key);
        values0.push(value);
        values1.push(group_sum);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_rank_first_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut rank: i64 = 1;
        let mut j: i64 = 0;
        while j < frame.rows {
            if frame.keys[j] == key {
                if frame.values[j] < value {
                    rank = rank + 1;
                } else {
                    if frame.values[j] == value && j < i {
                        rank = rank + 1;
                    };
                };
            };
            j = j + 1;
        };
        keys.push(key);
        values0.push(value);
        values1.push(rank as f64);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_rank_average_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut less_count: i64 = 0;
        let mut equal_count: i64 = 0;
        let mut j: i64 = 0;
        while j < frame.rows {
            if frame.keys[j] == key {
                if frame.values[j] < value {
                    less_count = less_count + 1;
                };
                if frame.values[j] == value {
                    equal_count = equal_count + 1;
                };
            };
            j = j + 1;
        };
        let rank: f64 = (less_count as f64) + (((equal_count + 1) as f64) / 2.0);
        keys.push(key);
        values0.push(value);
        values1.push(rank);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_rank_dense_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut rank: i64 = 1;
        let mut j: i64 = 0;
        while j < frame.rows {
            if frame.keys[j] == key {
                if frame.values[j] < value {
                    let candidate: f64 = frame.values[j];
                    let mut seen: i64 = 0;
                    let mut k: i64 = 0;
                    while k < j {
                        if frame.keys[k] == key {
                            if frame.values[k] == candidate {
                                seen = 1;
                            };
                        };
                        k = k + 1;
                    };
                    if seen == 0 {
                        rank = rank + 1;
                    };
                };
            };
            j = j + 1;
        };
        keys.push(key);
        values0.push(value);
        values1.push(rank as f64);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_rank_min_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut rank: i64 = 1;
        let mut j: i64 = 0;
        while j < frame.rows {
            if frame.keys[j] == key {
                if frame.values[j] < value {
                    rank = rank + 1;
                };
            };
            j = j + 1;
        };
        keys.push(key);
        values0.push(value);
        values1.push(rank as f64);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_rank_max_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut rank: i64 = 0;
        let mut j: i64 = 0;
        while j < frame.rows {
            if frame.keys[j] == key {
                if frame.values[j] <= value {
                    rank = rank + 1;
                };
            };
            j = j + 1;
        };
        keys.push(key);
        values0.push(value);
        values1.push(rank as f64);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_rank_pct_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut less_count: i64 = 0;
        let mut equal_count: i64 = 0;
        let mut group_count: i64 = 0;
        let mut j: i64 = 0;
        while j < frame.rows {
            if frame.keys[j] == key {
                group_count = group_count + 1;
                if frame.values[j] < value {
                    less_count = less_count + 1;
                };
                if frame.values[j] == value {
                    equal_count = equal_count + 1;
                };
            };
            j = j + 1;
        };
        let rank: f64 = (less_count as f64) + (((equal_count + 1) as f64) / 2.0);
        let mut rank_pct: f64 = 0.0;
        if group_count > 0 {
            rank_pct = rank / (group_count as f64);
        };
        keys.push(key);
        values0.push(value);
        values1.push(rank_pct);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_percent_of_total_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut group_sum: f64 = 0.0;
        let mut j: i64 = 0;
        while j < frame.rows {
            if frame.keys[j] == key {
                group_sum = group_sum + frame.values[j];
            };
            j = j + 1;
        };
        let mut percent: f64 = 0.0;
        if group_sum != 0.0 {
            percent = (value / group_sum) * 100.0;
        };
        keys.push(key);
        values0.push(value);
        values1.push(percent);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_size_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut group_count: i64 = 0;
        let mut j: i64 = 0;
        while j < frame.rows {
            if frame.keys[j] == key {
                group_count = group_count + 1;
            };
            j = j + 1;
        };
        keys.push(key);
        values0.push(value);
        values1.push(group_count as f64);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_cumsum_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut running: f64 = 0.0;
        let mut j: i64 = 0;
        while j <= i {
            if frame.keys[j] == key {
                running = running + frame.values[j];
            };
            j = j + 1;
        };
        keys.push(key);
        values0.push(value);
        values1.push(running);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_cumcount_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut count: i64 = 0;
        let mut j: i64 = 0;
        while j < i {
            if frame.keys[j] == key {
                count = count + 1;
            };
            j = j + 1;
        };
        keys.push(key);
        values0.push(value);
        values1.push(count as f64);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_shifted_value(frame: &FrameI64F64, derived_name: str, fill_value: f64) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut shifted: f64 = fill_value;
        let mut j: i64 = 0;
        while j < i {
            if frame.keys[j] == key {
                shifted = frame.values[j];
            };
            j = j + 1;
        };
        keys.push(key);
        values0.push(value);
        values1.push(shifted);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_diff_value(frame: &FrameI64F64, derived_name: str, fill_value: f64) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut previous: f64 = fill_value;
        let mut seen: bool = false;
        let mut j: i64 = 0;
        while j < i {
            if frame.keys[j] == key {
                previous = frame.values[j];
                seen = true;
            };
            j = j + 1;
        };
        keys.push(key);
        values0.push(value);
        if seen {
            values1.push(value - previous);
        } else {
            values1.push(fill_value);
        };
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_pct_change_value(frame: &FrameI64F64, derived_name: str, fill_value: f64) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut previous: f64 = fill_value;
        let mut seen: bool = false;
        let mut j: i64 = 0;
        while j < i {
            if frame.keys[j] == key {
                previous = frame.values[j];
                seen = true;
            };
            j = j + 1;
        };
        keys.push(key);
        values0.push(value);
        if seen {
            values1.push((value - previous) / previous);
        } else {
            values1.push(fill_value);
        };
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_expanding_mean_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut running_sum: f64 = 0.0;
        let mut count: i64 = 0;
        let mut j: i64 = 0;
        while j <= i {
            if frame.keys[j] == key {
                running_sum = running_sum + frame.values[j];
                count = count + 1;
            };
            j = j + 1;
        };
        keys.push(key);
        values0.push(value);
        values1.push(running_sum / (count as f64));
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_cummax_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut running: f64 = value;
        let mut j: i64 = 0;
        while j <= i {
            if frame.keys[j] == key {
                if frame.values[j] > running {
                    running = frame.values[j];
                };
            };
            j = j + 1;
        };
        keys.push(key);
        values0.push(value);
        values1.push(running);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_cummin_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut running: f64 = value;
        let mut j: i64 = 0;
        while j <= i {
            if frame.keys[j] == key {
                if frame.values[j] < running {
                    running = frame.values[j];
                };
            };
            j = j + 1;
        };
        keys.push(key);
        values0.push(value);
        values1.push(running);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_cumprod_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut running: f64 = 1.0;
        let mut j: i64 = 0;
        while j <= i {
            if frame.keys[j] == key {
                running = running * frame.values[j];
            };
            j = j + 1;
        };
        keys.push(key);
        values0.push(value);
        values1.push(running);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_group_rolling_mean_value(frame: &FrameI64F64, derived_name: str, window: i64) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut effective_window: i64 = window;
    if effective_window <= 0 {
        effective_window = 1;
    };

    let mut i: i64 = 0;
    while i < frame.rows {
        let key: i64 = frame.keys[i];
        let value: f64 = frame.values[i];
        let mut sum: f64 = 0.0;
        let mut count: i64 = 0;
        let mut j: i64 = i;
        while j >= 0 {
            if frame.keys[j] == key {
                if count < effective_window {
                    sum = sum + frame.values[j];
                    count = count + 1;
                };
            };
            j = j - 1;
        };
        keys.push(key);
        values0.push(value);
        values1.push(sum / (count as f64));
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_abs_deviation_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut total: f64 = 0.0;
    let mut i: i64 = 0;
    while i < frame.rows {
        total = total + frame.values[i];
        i = i + 1;
    };
    let mut mean: f64 = 0.0;
    if frame.rows > 0 {
        mean = total / (frame.rows as f64);
    };
    i = 0;
    while i < frame.rows {
        let value: f64 = frame.values[i];
        let mut deviation: f64 = value - mean;
        if deviation < 0.0 {
            deviation = 0.0 - deviation;
        };
        keys.push(frame.keys[i]);
        values0.push(value);
        values1.push(deviation);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_squared_deviation_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut total: f64 = 0.0;
    let mut i: i64 = 0;
    while i < frame.rows {
        total = total + frame.values[i];
        i = i + 1;
    };
    let mut mean: f64 = 0.0;
    if frame.rows > 0 {
        mean = total / (frame.rows as f64);
    };
    i = 0;
    while i < frame.rows {
        let value: f64 = frame.values[i];
        let deviation: f64 = value - mean;
        keys.push(frame.keys[i]);
        values0.push(value);
        values1.push(deviation * deviation);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_percent_of_total_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut total: f64 = 0.0;
    let mut i: i64 = 0;
    while i < frame.rows {
        total = total + frame.values[i];
        i = i + 1;
    };
    i = 0;
    while i < frame.rows {
        let value: f64 = frame.values[i];
        let mut percent: f64 = 0.0;
        if total != 0.0 {
            percent = (value / total) * 100.0;
        };
        keys.push(frame.keys[i]);
        values0.push(value);
        values1.push(percent);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_cumsum_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut running: f64 = 0.0;
    let mut i: i64 = 0;
    while i < frame.rows {
        let value: f64 = frame.values[i];
        running = running + value;
        keys.push(frame.keys[i]);
        values0.push(value);
        values1.push(running);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_cumprod_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut running: f64 = 1.0;
    let mut i: i64 = 0;
    while i < frame.rows {
        let value: f64 = frame.values[i];
        running = running * value;
        keys.push(frame.keys[i]);
        values0.push(value);
        values1.push(running);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn data_clip_f64(value: f64, lower: f64, upper: f64) -> f64 {
    if value < lower { return lower; };
    if value > upper { return upper; };
    return value;
}

fn frame_i64_f64_assign_clipped_value(frame: &FrameI64F64, derived_name: str, lower: f64, upper: f64) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let value: f64 = frame.values[i];
        keys.push(frame.keys[i]);
        values0.push(value);
        values1.push(data_clip_f64(value, lower, upper));
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_shifted_value(frame: &FrameI64F64, derived_name: str, fill_value: f64) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut previous: f64 = fill_value;
    let mut i: i64 = 0;
    while i < frame.rows {
        let value: f64 = frame.values[i];
        keys.push(frame.keys[i]);
        values0.push(value);
        values1.push(previous);
        previous = value;
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_pct_change_value(frame: &FrameI64F64, derived_name: str, fill_value: f64) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut previous: f64 = fill_value;
    let mut i: i64 = 0;
    while i < frame.rows {
        let value: f64 = frame.values[i];
        keys.push(frame.keys[i]);
        values0.push(value);
        if i == 0 {
            values1.push(fill_value);
        } else {
            values1.push((value - previous) / previous);
        };
        previous = value;
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_rolling_mean_value(frame: &FrameI64F64, derived_name: str, window: i64) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut effective_window: i64 = window;
    if effective_window <= 0 {
        effective_window = 1;
    };

    let mut i: i64 = 0;
    while i < frame.rows {
        let value: f64 = frame.values[i];
        let mut start: i64 = 0;
        if (i + 1) > effective_window {
            start = i + 1 - effective_window;
        };
        let mut sum: f64 = 0.0;
        let mut count: i64 = 0;
        let mut j: i64 = start;
        while j <= i {
            sum = sum + frame.values[j];
            count = count + 1;
            j = j + 1;
        };
        keys.push(frame.keys[i]);
        values0.push(value);
        values1.push(sum / (count as f64));
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_expanding_mean_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut running_sum: f64 = 0.0;
    let mut i: i64 = 0;
    while i < frame.rows {
        let value: f64 = frame.values[i];
        running_sum = running_sum + value;
        keys.push(frame.keys[i]);
        values0.push(value);
        values1.push(running_sum / ((i + 1) as f64));
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_where_value_ge(frame: &FrameI64F64, derived_name: str, minimum: f64, other: f64) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        let value: f64 = frame.values[i];
        keys.push(frame.keys[i]);
        values0.push(value);
        if value >= minimum {
            values1.push(value);
        } else {
            values1.push(other);
        };
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_diff_value(frame: &FrameI64F64, derived_name: str, fill_value: f64) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut previous: f64 = fill_value;
    let mut i: i64 = 0;
    while i < frame.rows {
        let value: f64 = frame.values[i];
        keys.push(frame.keys[i]);
        values0.push(value);
        if i == 0 {
            values1.push(fill_value);
        } else {
            values1.push(value - previous);
        };
        previous = value;
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_cummax_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut running: f64 = 0.0;
    let mut i: i64 = 0;
    while i < frame.rows {
        let value: f64 = frame.values[i];
        if i == 0 {
            running = value;
        } else {
            if value > running {
                running = value;
            };
        };
        keys.push(frame.keys[i]);
        values0.push(value);
        values1.push(running);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_assign_cummin_value(frame: &FrameI64F64, derived_name: str) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut running: f64 = 0.0;
    let mut i: i64 = 0;
    while i < frame.rows {
        let value: f64 = frame.values[i];
        if i == 0 {
            running = value;
        } else {
            if value < running {
                running = value;
            };
        };
        keys.push(frame.keys[i]);
        values0.push(value);
        values1.push(running);
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value_name, derived_name, keys, values0, values1);
}

fn frame_i64_f64_sort_by_value_desc(frame: &FrameI64F64) -> FrameI64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        keys.push(frame.keys[i]);
        values.push(frame.values[i]);
        i = i + 1;
    };

    i = 1;
    while i < frame.rows {
        let key: i64 = keys[i];
        let value: f64 = values[i];
        let mut j: i64 = i - 1;
        while j >= 0 && values[j] < value {
            vec_set(keys, j + 1, keys[j]);
            vec_set(values, j + 1, values[j]);
            j = j - 1;
        };
        vec_set(keys, j + 1, key);
        vec_set(values, j + 1, value);
        i = i + 1;
    };

    return frame_i64_f64_from_vec(frame.key_name, frame.value_name, keys, values);
}

fn frame_i64_f64_sort_by_value_asc(frame: &FrameI64F64) -> FrameI64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        keys.push(frame.keys[i]);
        values.push(frame.values[i]);
        i = i + 1;
    };

    i = 1;
    while i < frame.rows {
        let key: i64 = keys[i];
        let value: f64 = values[i];
        let mut j: i64 = i - 1;
        while j >= 0 && values[j] > value {
            vec_set(keys, j + 1, keys[j]);
            vec_set(values, j + 1, values[j]);
            j = j - 1;
        };
        vec_set(keys, j + 1, key);
        vec_set(values, j + 1, value);
        i = i + 1;
    };

    return frame_i64_f64_from_vec(frame.key_name, frame.value_name, keys, values);
}

fn frame_i64_f64_head(frame: &FrameI64F64, n: i64) -> FrameI64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut limit: i64 = n;
    if limit < 0 {
        limit = 0;
    };
    if limit > frame.rows {
        limit = frame.rows;
    };

    let mut i: i64 = 0;
    while i < limit {
        keys.push(frame.keys[i]);
        values.push(frame.values[i]);
        i = i + 1;
    };
    return frame_i64_f64_from_vec(frame.key_name, frame.value_name, keys, values);
}

fn frame_i64_f64_tail(frame: &FrameI64F64, n: i64) -> FrameI64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut start: i64 = 0;
    if n < frame.rows {
        start = frame.rows - n;
    };
    if n <= 0 {
        start = frame.rows;
    };

    let mut i: i64 = start;
    while i < frame.rows {
        keys.push(frame.keys[i]);
        values.push(frame.values[i]);
        i = i + 1;
    };
    return frame_i64_f64_from_vec(frame.key_name, frame.value_name, keys, values);
}

fn frame_i64_f64_f64_filter_value0_ge(frame: &FrameI64F64F64, minimum: f64) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        if frame.values0[i] >= minimum {
            keys.push(frame.keys[i]);
            values0.push(frame.values0[i]);
            values1.push(frame.values1[i]);
        };
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value0_name, frame.value1_name, keys, values0, values1);
}

fn frame_i64_f64_f64_filter_values_ge(frame: &FrameI64F64F64, minimum0: f64, minimum1: f64) -> FrameI64F64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values0: Vec<f64> = Vec::new();
    let mut values1: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        if frame.values0[i] >= minimum0 && frame.values1[i] >= minimum1 {
            keys.push(frame.keys[i]);
            values0.push(frame.values0[i]);
            values1.push(frame.values1[i]);
        };
        i = i + 1;
    };
    return frame_i64_f64_f64_from_vec(frame.key_name, frame.value0_name, frame.value1_name, keys, values0, values1);
}

fn frame_i64_nullable_f64_dropna(frame: &FrameI64NullableF64) -> FrameI64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        if frame.valid[i] == 1 {
            keys.push(frame.keys[i]);
            values.push(frame.values[i]);
        };
        i = i + 1;
    };
    return frame_i64_f64_from_vec(frame.key_name, frame.value_name, keys, values);
}

fn frame_str_nullable_f64_dropna(frame: &FrameStrNullableF64) -> FrameStrF64 {
    let mut keys: Vec<str> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        if frame.valid[i] == 1 {
            keys.push(vec_get(frame.keys, i));
            values.push(frame.values[i]);
        };
        i = i + 1;
    };
    return frame_str_f64_from_vec(frame.key_name, frame.value_name, keys, values);
}

fn frame_str_nullable_f64_fillna(frame: &FrameStrNullableF64, fill_value: f64) -> FrameStrF64 {
    let mut keys: Vec<str> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        keys.push(vec_get(frame.keys, i));
        if frame.valid[i] == 1 {
            values.push(frame.values[i]);
        } else {
            values.push(fill_value);
        };
        i = i + 1;
    };
    return frame_str_f64_from_vec(frame.key_name, frame.value_name, keys, values);
}

fn frame_str_nullable_f64_mean(frame: &FrameStrNullableF64) -> f64 {
    let mut sum: f64 = 0.0;
    let mut count: i64 = 0;
    let mut i: i64 = 0;
    while i < frame.rows {
        if frame.valid[i] == 1 {
            sum = sum + frame.values[i];
            count = count + 1;
        };
        i = i + 1;
    };
    if count == 0 { return 0.0; };
    return sum / (count as f64);
}

fn frame_i64_nullable_f64_fillna(frame: &FrameI64NullableF64, fill_value: f64) -> FrameI64F64 {
    let mut keys: Vec<i64> = Vec::new();
    let mut values: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        keys.push(frame.keys[i]);
        if frame.valid[i] == 1 {
            values.push(frame.values[i]);
        } else {
            values.push(fill_value);
        };
        i = i + 1;
    };
    return frame_i64_f64_from_vec(frame.key_name, frame.value_name, keys, values);
}

fn frame_i64_nullable_f64_mean(frame: &FrameI64NullableF64) -> f64 {
    let mut sum: f64 = 0.0;
    let mut count: i64 = 0;
    let mut i: i64 = 0;
    while i < frame.rows {
        if frame.valid[i] == 1 {
            sum = sum + frame.values[i];
            count = count + 1;
        };
        i = i + 1;
    };
    if count == 0 { return 0.0; };
    return sum / (count as f64);
}

fn frame_i64_f64_values_tensor(frame: &FrameI64F64) -> TensorF64 {
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        data.push(frame.values[i]);
        i = i + 1;
    };
    return tensor_f64_from_vec(frame.rows, 1, data);
}

fn frame_str_f64_values_tensor(frame: &FrameStrF64) -> TensorF64 {
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        data.push(frame.values[i]);
        i = i + 1;
    };
    return tensor_f64_from_vec(frame.rows, 1, data);
}

fn frame_i64_f64_f64_values_tensor(frame: &FrameI64F64F64) -> TensorF64 {
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < frame.rows {
        data.push(frame.values0[i]);
        data.push(frame.values1[i]);
        i = i + 1;
    };
    return tensor_f64_from_vec(frame.rows, 2, data);
}

fn grouped_i64_f64_mean(grouped: &GroupedI64F64, group_idx: i64) -> f64 {
    return grouped.sums[group_idx] / (grouped.counts[group_idx] as f64);
}

fn grouped_i64_f64_f64_mean0(grouped: &GroupedI64F64F64, group_idx: i64) -> f64 {
    return grouped.sums0[group_idx] / (grouped.counts[group_idx] as f64);
}

fn grouped_i64_f64_f64_mean1(grouped: &GroupedI64F64F64, group_idx: i64) -> f64 {
    return grouped.sums1[group_idx] / (grouped.counts[group_idx] as f64);
}

fn grouped_str_f64_mean(grouped: &GroupedStrF64, group_idx: i64) -> f64 {
    return grouped.sums[group_idx] / (grouped.counts[group_idx] as f64);
}

fn frame_i64_f64_print_key_value(label: str, frame: &FrameI64F64) -> i64 {
    print(label);
    let mut i: i64 = 0;
    while i < frame.rows {
        print_int(frame.keys[i]);
        print_f64(frame.values[i]);
        i = i + 1;
    };
    return 0;
}

fn frame_str_f64_print_key_value(label: str, frame: &FrameStrF64) -> i64 {
    print(label);
    let mut i: i64 = 0;
    while i < frame.rows {
        print(vec_get(frame.keys, i));
        print_f64(frame.values[i]);
        i = i + 1;
    };
    return 0;
}

fn frame_i64_f64_f64_print_key_values(label: str, frame: &FrameI64F64F64) -> i64 {
    print(label);
    let mut i: i64 = 0;
    while i < frame.rows {
        print_int(frame.keys[i]);
        print_f64(frame.values0[i]);
        print_f64(frame.values1[i]);
        i = i + 1;
    };
    return 0;
}

fn frame_i64_nullable_f64_print_valid_mask(label: str, frame: &FrameI64NullableF64) -> i64 {
    print(label);
    let mut i: i64 = 0;
    while i < frame.rows {
        print_int(frame.valid[i]);
        i = i + 1;
    };
    return 0;
}

fn frame_str_nullable_f64_print_valid_mask(label: str, frame: &FrameStrNullableF64) -> i64 {
    print(label);
    let mut i: i64 = 0;
    while i < frame.rows {
        print_int(frame.valid[i]);
        i = i + 1;
    };
    return 0;
}

fn grouped_i64_f64_print_key_sum_mean(label: str, grouped: &GroupedI64F64) -> i64 {
    print(label);
    let mut i: i64 = 0;
    while i < grouped.groups {
        print_int(grouped.keys[i]);
        print_f64(grouped.sums[i]);
        print_f64(grouped_i64_f64_mean(grouped, i));
        i = i + 1;
    };
    return 0;
}

fn grouped_stats_i64_f64_print_key_count_min_max(label: str, grouped: &GroupedStatsI64F64) -> i64 {
    print(label);
    let mut i: i64 = 0;
    while i < grouped.groups {
        print_int(grouped.keys[i]);
        print_int(grouped.counts[i]);
        print_f64(grouped.mins[i]);
        print_f64(grouped.maxs[i]);
        i = i + 1;
    };
    return 0;
}

fn grouped_i64_f64_f64_print_key_sum_mean(label: str, grouped: &GroupedI64F64F64) -> i64 {
    print(label);
    let mut i: i64 = 0;
    while i < grouped.groups {
        print_int(grouped.keys[i]);
        print_f64(grouped.sums0[i]);
        print_f64(grouped_i64_f64_f64_mean0(grouped, i));
        print_f64(grouped.sums1[i]);
        print_f64(grouped_i64_f64_f64_mean1(grouped, i));
        i = i + 1;
    };
    return 0;
}

fn grouped_str_f64_print_key_sum_mean(label: str, grouped: &GroupedStrF64) -> i64 {
    print(label);
    let mut i: i64 = 0;
    while i < grouped.groups {
        print(vec_get(grouped.keys, i));
        print_f64(grouped.sums[i]);
        print_f64(grouped_str_f64_mean(grouped, i));
        i = i + 1;
    };
    return 0;
}

fn value_counts_str_print_key_count(label: str, counts: &ValueCountsStr) -> i64 {
    print(label);
    let mut i: i64 = 0;
    while i < counts.groups {
        print(vec_get(counts.keys, i));
        print_int(counts.counts[i]);
        i = i + 1;
    };
    return 0;
}

fn value_counts_i64_print_key_count(label: str, counts: &ValueCountsI64) -> i64 {
    print(label);
    let mut i: i64 = 0;
    while i < counts.groups {
        print_int(counts.keys[i]);
        print_int(counts.counts[i]);
        i = i + 1;
    };
    return 0;
}

fn joined_str_f64_f64_print(label: str, joined: &JoinedStrF64F64) -> i64 {
    print(label);
    let mut i: i64 = 0;
    while i < joined.rows {
        print(vec_get(joined.keys, i));
        print_f64(joined.left_values[i]);
        print_f64(joined.right_values[i]);
        i = i + 1;
    };
    return 0;
}

fn left_joined_str_f64_f64_print(label: str, joined: &LeftJoinedStrF64F64) -> i64 {
    print(label);
    let mut i: i64 = 0;
    while i < joined.rows {
        print(vec_get(joined.keys, i));
        print_f64(joined.left_values[i]);
        print_int(joined.right_valid[i]);
        print_f64(joined.right_values[i]);
        i = i + 1;
    };
    return 0;
}

fn right_joined_str_f64_f64_print(label: str, joined: &RightJoinedStrF64F64) -> i64 {
    print(label);
    let mut i: i64 = 0;
    while i < joined.rows {
        print(vec_get(joined.keys, i));
        print_int(joined.left_valid[i]);
        print_f64(joined.left_values[i]);
        print_f64(joined.right_values[i]);
        i = i + 1;
    };
    return 0;
}

fn outer_joined_str_f64_f64_print(label: str, joined: &OuterJoinedStrF64F64) -> i64 {
    print(label);
    let mut i: i64 = 0;
    while i < joined.rows {
        print(vec_get(joined.keys, i));
        print_int(joined.left_valid[i]);
        print_f64(joined.left_values[i]);
        print_int(joined.right_valid[i]);
        print_f64(joined.right_values[i]);
        i = i + 1;
    };
    return 0;
}

fn left_joined_i64_f64_f64_print(label: str, joined: &LeftJoinedI64F64F64) -> i64 {
    print(label);
    let mut i: i64 = 0;
    while i < joined.rows {
        print_int(joined.keys[i]);
        print_f64(joined.left_values[i]);
        print_int(joined.right_valid[i]);
        print_f64(joined.right_values[i]);
        i = i + 1;
    };
    return 0;
}

fn right_joined_i64_f64_f64_print(label: str, joined: &RightJoinedI64F64F64) -> i64 {
    print(label);
    let mut i: i64 = 0;
    while i < joined.rows {
        print_int(joined.keys[i]);
        print_int(joined.left_valid[i]);
        print_f64(joined.left_values[i]);
        print_f64(joined.right_values[i]);
        i = i + 1;
    };
    return 0;
}

fn outer_joined_i64_f64_f64_print(label: str, joined: &OuterJoinedI64F64F64) -> i64 {
    print(label);
    let mut i: i64 = 0;
    while i < joined.rows {
        print_int(joined.keys[i]);
        print_int(joined.left_valid[i]);
        print_f64(joined.left_values[i]);
        print_int(joined.right_valid[i]);
        print_f64(joined.right_values[i]);
        i = i + 1;
    };
    return 0;
}

fn describe_f64_print(label: str, desc: &DescribeF64) -> i64 {
    print(label);
    print_int(desc.count);
    print_f64(desc.mean);
    print_f64(desc.min);
    print_f64(desc.max);
    return 0;
}

fn joined_i64_f64_f64_print(label: str, joined: &JoinedI64F64F64) -> i64 {
    print(label);
    let mut i: i64 = 0;
    while i < joined.rows {
        print_int(joined.keys[i]);
        print_f64(joined.left_values[i]);
        print_f64(joined.right_values[i]);
        i = i + 1;
    };
    return 0;
}
