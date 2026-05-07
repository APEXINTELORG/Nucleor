// rods/ml/data_facade — pandas-style FrameI64F64 + nullable variant (typed CSV ingest, groupby, inner-join, filter, dropna/fillna)
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
struct GroupedI64F64 {
    groups: i64,
    keys: Vec<i64>,
    sums: Vec<f64>,
    counts: Vec<i64>
}

#[repr(C)]
struct JoinedI64F64F64 {
    rows: i64,
    keys: Vec<i64>,
    left_values: Vec<f64>,
    right_values: Vec<f64>
}

fn frame_i64_f64_from_vec(key_name: str, value_name: str, keys: Vec<i64>, values: Vec<f64>) -> FrameI64F64 {
    return FrameI64F64 {
        key_name: key_name,
        value_name: value_name,
        rows: vec_len(keys),
        keys: keys,
        values: values
    };
}

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

fn frame_i64_f64_from_csv_i64(path: str, key_name: str, value_name: str, has_header: i64) -> FrameI64F64 {
    let raw: str = file_read_string(path);
    return frame_i64_f64_from_csv_i64_text(raw, key_name, value_name, has_header);
}

fn frame_i64_nullable_f64_from_csv_i64(path: str, key_name: str, value_name: str, has_header: i64) -> FrameI64NullableF64 {
    let raw: str = file_read_string(path);
    return frame_i64_nullable_f64_from_csv_i64_text(raw, key_name, value_name, has_header);
}

fn grouped_i64_f64_find_key(grouped: &GroupedI64F64, key: i64) -> i64 {
    let mut i: i64 = 0;
    while i < grouped.groups {
        if grouped.keys[i] == key { return i; };
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

fn grouped_i64_f64_mean(grouped: &GroupedI64F64, group_idx: i64) -> f64 {
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

fn frame_i64_nullable_f64_print_valid_mask(label: str, frame: &FrameI64NullableF64) -> i64 {
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
