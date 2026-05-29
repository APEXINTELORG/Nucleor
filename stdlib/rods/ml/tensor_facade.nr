// rods/ml/tensor_facade — Parity-flavored TensorF64/F32/I64 surface (matmul, broadcast, reductions, slicing, reshape)
//
import "stdlib/rods/ml/dtype_core.nr"
import "stdlib/rods/ml/shape_core.nr"

// tensor_facade.nr - first executable tensor facade.
//
// This MVP uses concrete f64 tensors so it compiles today, while carrying
// dtype, accumulator, and numeric-policy metadata that future generic kernels
// can specialize over.

#[repr(C)]
struct TensorF64 {
    shape: Shape2,
    dtype: i64,
    accumulator_dtype: i64,
    policy: i64,
    data: Vec<f64>
}

#[repr(C)]
// HON-3: this type is f32 in NAME and dtype-tag only. Its storage is
// `Vec<i64>` (raw bit-pattern / metadata lane), NOT a real f32 buffer —
// there is no native f32 tensor kernel behind it yet. Treat `data` as
// opaque tagged storage; do not assume IEEE-754 f32 element semantics.
struct TensorF32 {
    shape: Shape2,
    dtype: i64,
    accumulator_dtype: i64,
    policy: i64,
    data: Vec<i64>
}

#[repr(C)]
struct TensorI64 {
    shape: Shape2,
    dtype: i64,
    accumulator_dtype: i64,
    policy: i64,
    data: Vec<i64>
}

fn tensor_f64_from_vec(rows: i64, cols: i64, data: Vec<f64>) -> TensorF64 {
    return TensorF64 {
        shape: shape2(rows, cols),
        dtype: dtype_f64(),
        accumulator_dtype: dtype_default_accumulator(dtype_f64()),
        policy: policy_strict(),
        data: data
    };
}

fn parse_f64_decimal(cell: str) -> f64 {
    let s: str = str_trim(cell);
    return f64_from_bits(str_to_f64(s));
}

fn tensor_f64_from_csv_i64_text(raw: str, rows: i64, cols: i64, has_header: i64) -> TensorF64 {
    let lines: Vec<str> = str_lines(raw);
    let mut data: Vec<f64> = Vec::new();
    let mut line_idx: i64 = 0;
    if has_header == 1 { line_idx = 1; };

    while line_idx < vec_len(lines) {
        let line: str = str_trim(vec_get(lines, line_idx));
        if str_len(line) > 0 {
            let cells: Vec<str> = str_split(line, ",");
            let mut c: i64 = 0;
            while c < cols {
                if c < vec_len(cells) {
                    let cell: str = str_trim(vec_get(cells, c));
                    data.push(str_to_i64(cell) as f64);
                };
                c = c + 1;
            };
        };
        line_idx = line_idx + 1;
    };

    if vec_len(data) != rows * cols {
        print("csv error: parsed cell count does not match requested shape");
        return tensor_f64_zeros(0, 0);
    };
    return tensor_f64_from_vec(rows, cols, data);
}

fn tensor_f64_from_csv_f64_text(raw: str, rows: i64, cols: i64, has_header: i64) -> TensorF64 {
    let lines: Vec<str> = str_lines(raw);
    let mut data: Vec<f64> = Vec::new();
    let mut line_idx: i64 = 0;
    if has_header == 1 { line_idx = 1; };

    while line_idx < vec_len(lines) {
        let line: str = str_trim(vec_get(lines, line_idx));
        if str_len(line) > 0 {
            let cells: Vec<str> = str_split(line, ",");
            let mut c: i64 = 0;
            while c < cols {
                if c < vec_len(cells) {
                    let cell: str = str_trim(vec_get(cells, c));
                    data.push(parse_f64_decimal(cell));
                };
                c = c + 1;
            };
        };
        line_idx = line_idx + 1;
    };

    if vec_len(data) != rows * cols {
        print("csv error: parsed cell count does not match requested shape");
        return tensor_f64_zeros(0, 0);
    };
    return tensor_f64_from_vec(rows, cols, data);
}

fn tensor_f64_from_csv_i64(path: str, rows: i64, cols: i64, has_header: i64) -> TensorF64 {
    let raw: str = file_read_string(path);
    return tensor_f64_from_csv_i64_text(raw, rows, cols, has_header);
}

fn tensor_f64_from_csv_f64(path: str, rows: i64, cols: i64, has_header: i64) -> TensorF64 {
    let raw: str = file_read_string(path);
    return tensor_f64_from_csv_f64_text(raw, rows, cols, has_header);
}

fn tensor_f32_from_vec(rows: i64, cols: i64, data: Vec<i64>) -> TensorF32 {
    return TensorF32 {
        shape: shape2(rows, cols),
        dtype: dtype_f32(),
        accumulator_dtype: dtype_default_accumulator(dtype_f32()),
        policy: policy_strict(),
        data: data
    };
}

fn tensor_i64_from_vec(rows: i64, cols: i64, data: Vec<i64>) -> TensorI64 {
    return TensorI64 {
        shape: shape2(rows, cols),
        dtype: dtype_i64(),
        accumulator_dtype: dtype_default_accumulator(dtype_i64()),
        policy: policy_strict(),
        data: data
    };
}

fn tensor_f64_full(rows: i64, cols: i64, value: f64) -> TensorF64 {
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < rows * cols {
        data.push(value);
        i = i + 1;
    };
    return tensor_f64_from_vec(rows, cols, data);
}

fn tensor_f32_full(rows: i64, cols: i64, value: i64) -> TensorF32 {
    let mut data: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < rows * cols {
        data.push(value);
        i = i + 1;
    };
    return tensor_f32_from_vec(rows, cols, data);
}

fn tensor_i64_full(rows: i64, cols: i64, value: i64) -> TensorI64 {
    let mut data: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < rows * cols {
        data.push(value);
        i = i + 1;
    };
    return tensor_i64_from_vec(rows, cols, data);
}

fn tensor_f64_zeros(rows: i64, cols: i64) -> TensorF64 {
    return tensor_f64_full(rows, cols, 0.0);
}

fn tensor_f32_zeros(rows: i64, cols: i64) -> TensorF32 {
    return tensor_f32_full(rows, cols, f32_from_int(0));
}

fn tensor_i64_zeros(rows: i64, cols: i64) -> TensorI64 {
    return tensor_i64_full(rows, cols, 0);
}

fn tensor_f64_len(t: &TensorF64) -> i64 {
    return t.shape.rows * t.shape.cols;
}

fn tensor_f32_len(t: &TensorF32) -> i64 {
    return t.shape.rows * t.shape.cols;
}

fn tensor_i64_len(t: &TensorI64) -> i64 {
    return t.shape.rows * t.shape.cols;
}

fn tensor_f64_index(t: &TensorF64, row: i64, col: i64) -> i64 {
    return row * t.shape.cols + col;
}

fn tensor_f32_index(t: &TensorF32, row: i64, col: i64) -> i64 {
    return row * t.shape.cols + col;
}

fn tensor_i64_index(t: &TensorI64, row: i64, col: i64) -> i64 {
    return row * t.shape.cols + col;
}

fn tensor_f64_at(t: &TensorF64, row: i64, col: i64) -> f64 {
    return t.data[tensor_f64_index(t, row, col)];
}

fn tensor_f32_at(t: &TensorF32, row: i64, col: i64) -> i64 {
    return t.data[tensor_f32_index(t, row, col)];
}

fn tensor_i64_at(t: &TensorI64, row: i64, col: i64) -> i64 {
    return t.data[tensor_i64_index(t, row, col)];
}

fn tensor_f64_sum(t: &TensorF64) -> f64 {
    let mut acc: f64 = 0.0;
    let mut i: i64 = 0;
    while i < tensor_f64_len(t) {
        acc = acc + t.data[i];
        i = i + 1;
    };
    return acc;
}

fn tensor_f32_sum(t: &TensorF32) -> i64 {
    let mut acc: i64 = f32_from_int(0);
    let mut i: i64 = 0;
    while i < tensor_f32_len(t) {
        acc = f32_add(acc, t.data[i]);
        i = i + 1;
    };
    return acc;
}

fn tensor_i64_sum(t: &TensorI64) -> i64 {
    let mut acc: i64 = 0;
    let mut i: i64 = 0;
    while i < tensor_i64_len(t) {
        acc = acc + t.data[i];
        i = i + 1;
    };
    return acc;
}

fn tensor_f64_mean(t: &TensorF64) -> f64 {
    return tensor_f64_sum(t) / (tensor_f64_len(t) as f64);
}

fn tensor_f32_mean(t: &TensorF32) -> i64 {
    return f32_div(tensor_f32_sum(t), f32_from_int(tensor_f32_len(t)));
}

fn tensor_f64_add(a: &TensorF64, b: &TensorF64) -> TensorF64 {
    if shape2_assert_same(&a.shape, &b.shape) != 0 {
        return tensor_f64_zeros(0, 0);
    };
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(a) {
        data.push(a.data[i] + b.data[i]);
        i = i + 1;
    };
    return tensor_f64_from_vec(a.shape.rows, a.shape.cols, data);
}

fn tensor_f64_mul(a: &TensorF64, b: &TensorF64) -> TensorF64 {
    if shape2_assert_same(&a.shape, &b.shape) != 0 {
        return tensor_f64_zeros(0, 0);
    };
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(a) {
        data.push(a.data[i] * b.data[i]);
        i = i + 1;
    };
    return tensor_f64_from_vec(a.shape.rows, a.shape.cols, data);
}

fn tensor_f64_div(a: &TensorF64, b: &TensorF64) -> TensorF64 {
    if shape2_assert_same(&a.shape, &b.shape) != 0 {
        return tensor_f64_zeros(0, 0);
    };
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(a) {
        data.push(a.data[i] / b.data[i]);
        i = i + 1;
    };
    return tensor_f64_from_vec(a.shape.rows, a.shape.cols, data);
}

fn tensor_f64_powi(a: &TensorF64, exponent: i64) -> TensorF64 {
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(a) {
        let mut acc: f64 = 1.0;
        let mut k: i64 = 0;
        while k < exponent {
            acc = acc * a.data[i];
            k = k + 1;
        };
        data.push(acc);
        i = i + 1;
    };
    return tensor_f64_from_vec(a.shape.rows, a.shape.cols, data);
}

fn tensor_f64_scale(a: &TensorF64, scale: f64) -> TensorF64 {
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(a) {
        data.push(a.data[i] * scale);
        i = i + 1;
    };
    return tensor_f64_from_vec(a.shape.rows, a.shape.cols, data);
}

fn tensor_f32_mul(a: &TensorF32, b: &TensorF32) -> TensorF32 {
    if shape2_assert_same(&a.shape, &b.shape) != 0 {
        return tensor_f32_zeros(0, 0);
    };
    let mut data: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f32_len(a) {
        data.push(f32_mul(a.data[i], b.data[i]));
        i = i + 1;
    };
    return tensor_f32_from_vec(a.shape.rows, a.shape.cols, data);
}

fn tensor_f32_div(a: &TensorF32, b: &TensorF32) -> TensorF32 {
    if shape2_assert_same(&a.shape, &b.shape) != 0 {
        return tensor_f32_zeros(0, 0);
    };
    let mut data: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f32_len(a) {
        data.push(f32_div(a.data[i], b.data[i]));
        i = i + 1;
    };
    return tensor_f32_from_vec(a.shape.rows, a.shape.cols, data);
}

fn tensor_f32_powi(a: &TensorF32, exponent: i64) -> TensorF32 {
    if exponent < 0 {
        print("pow error: f32 negative exponents are not implemented");
        return tensor_f32_zeros(0, 0);
    };
    let mut data: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f32_len(a) {
        let mut acc: i64 = f32_from_int(1);
        let mut e: i64 = 0;
        while e < exponent {
            acc = f32_mul(acc, a.data[i]);
            e = e + 1;
        };
        data.push(acc);
        i = i + 1;
    };
    return tensor_f32_from_vec(a.shape.rows, a.shape.cols, data);
}

fn tensor_f64_reshape(a: &TensorF64, rows: i64, cols: i64) -> TensorF64 {
    if rows * cols != tensor_f64_len(a) {
        print("shape error: reshape total size must match");
        return tensor_f64_zeros(0, 0);
    };
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(a) {
        data.push(a.data[i]);
        i = i + 1;
    };
    return tensor_f64_from_vec(rows, cols, data);
}

fn tensor_f64_transpose(a: &TensorF64) -> TensorF64 {
    let mut data: Vec<f64> = Vec::new();
    let mut c: i64 = 0;
    while c < a.shape.cols {
        let mut r: i64 = 0;
        while r < a.shape.rows {
            data.push(tensor_f64_at(a, r, c));
            r = r + 1;
        };
        c = c + 1;
    };
    return tensor_f64_from_vec(a.shape.cols, a.shape.rows, data);
}

fn tensor_f64_slice(a: &TensorF64, row_start: i64, row_end: i64, col_start: i64, col_end: i64) -> TensorF64 {
    if row_start < 0 { print("slice error: row_start below zero"); return tensor_f64_zeros(0, 0); };
    if col_start < 0 { print("slice error: col_start below zero"); return tensor_f64_zeros(0, 0); };
    if row_end > a.shape.rows { print("slice error: row_end beyond rows"); return tensor_f64_zeros(0, 0); };
    if col_end > a.shape.cols { print("slice error: col_end beyond cols"); return tensor_f64_zeros(0, 0); };
    if row_end < row_start { print("slice error: row_end before row_start"); return tensor_f64_zeros(0, 0); };
    if col_end < col_start { print("slice error: col_end before col_start"); return tensor_f64_zeros(0, 0); };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = row_start;
    while r < row_end {
        let mut c: i64 = col_start;
        while c < col_end {
            data.push(tensor_f64_at(a, r, c));
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(row_end - row_start, col_end - col_start, data);
}

fn tensor_f64_select_rows(a: &TensorF64, indices: &TensorI64) -> TensorF64 {
    let out_rows: i64 = tensor_i64_len(indices);
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < out_rows {
        let src_row: i64 = indices.data[i];
        if src_row < 0 {
            print("select rows error: row below zero");
            return tensor_f64_zeros(0, 0);
        };
        if src_row >= a.shape.rows {
            print("select rows error: row beyond input rows");
            return tensor_f64_zeros(0, 0);
        };
        let mut c: i64 = 0;
        while c < a.shape.cols {
            data.push(tensor_f64_at(a, src_row, c));
            c = c + 1;
        };
        i = i + 1;
    };
    return tensor_f64_from_vec(out_rows, a.shape.cols, data);
}

fn tensor_i64_select_rows(a: &TensorI64, indices: &TensorI64) -> TensorI64 {
    let out_rows: i64 = tensor_i64_len(indices);
    let mut data: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < out_rows {
        let src_row: i64 = indices.data[i];
        if src_row < 0 {
            print("select rows error: row below zero");
            return tensor_i64_zeros(0, 0);
        };
        if src_row >= a.shape.rows {
            print("select rows error: row beyond input rows");
            return tensor_i64_zeros(0, 0);
        };
        let mut c: i64 = 0;
        while c < a.shape.cols {
            data.push(tensor_i64_at(a, src_row, c));
            c = c + 1;
        };
        i = i + 1;
    };
    return tensor_i64_from_vec(out_rows, a.shape.cols, data);
}

fn tensor_f64_broadcast_add_row(a: &TensorF64, row: &TensorF64) -> TensorF64 {
    if row.shape.rows != 1 {
        print("broadcast error: right tensor must have one row");
        return tensor_f64_zeros(0, 0);
    };
    if row.shape.cols != a.shape.cols {
        print("broadcast error: right cols must equal left cols");
        return tensor_f64_zeros(0, 0);
    };
    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < a.shape.rows {
        let mut c: i64 = 0;
        while c < a.shape.cols {
            data.push(tensor_f64_at(a, r, c) + tensor_f64_at(row, 0, c));
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(a.shape.rows, a.shape.cols, data);
}

fn tensor_f64_matmul(a: &TensorF64, b: &TensorF64) -> TensorF64 {
    if shape2_assert_matmul(&a.shape, &b.shape) != 0 {
        return tensor_f64_zeros(0, 0);
    };
    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < a.shape.rows {
        let mut c: i64 = 0;
        while c < b.shape.cols {
            let mut acc: f64 = 0.0;
            let mut k: i64 = 0;
            while k < a.shape.cols {
                acc = acc + tensor_f64_at(a, r, k) * tensor_f64_at(b, k, c);
                k = k + 1;
            };
            data.push(acc);
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(a.shape.rows, b.shape.cols, data);
}

fn tensor_f64_matvec(a: &TensorF64, x: &TensorF64) -> TensorF64 {
    if x.shape.cols != 1 {
        print("shape error: vector must be a single-column tensor");
        return tensor_f64_zeros(0, 0);
    };
    if a.shape.cols != x.shape.rows {
        print("shape error: matrix cols must equal vector rows");
        return tensor_f64_zeros(0, 0);
    };
    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < a.shape.rows {
        let mut acc: f64 = 0.0;
        let mut c: i64 = 0;
        while c < a.shape.cols {
            acc = acc + tensor_f64_at(a, r, c) * tensor_f64_at(x, c, 0);
            c = c + 1;
        };
        data.push(acc);
        r = r + 1;
    };
    return tensor_f64_from_vec(a.shape.rows, 1, data);
}

fn tensor_f32_matmul(a: &TensorF32, b: &TensorF32) -> TensorF32 {
    if shape2_assert_matmul(&a.shape, &b.shape) != 0 {
        return tensor_f32_zeros(0, 0);
    };
    let mut data: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < a.shape.rows {
        let mut c: i64 = 0;
        while c < b.shape.cols {
            let mut acc: i64 = f32_from_int(0);
            let mut k: i64 = 0;
            while k < a.shape.cols {
                acc = f32_add(acc, f32_mul(tensor_f32_at(a, r, k), tensor_f32_at(b, k, c)));
                k = k + 1;
            };
            data.push(acc);
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f32_from_vec(a.shape.rows, b.shape.cols, data);
}

fn tensor_f32_matvec(a: &TensorF32, x: &TensorF32) -> TensorF32 {
    if x.shape.cols != 1 {
        print("shape error: vector must be a single-column tensor");
        return tensor_f32_zeros(0, 0);
    };
    if a.shape.cols != x.shape.rows {
        print("shape error: matrix cols must equal vector rows");
        return tensor_f32_zeros(0, 0);
    };
    let mut data: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < a.shape.rows {
        let mut acc: i64 = f32_from_int(0);
        let mut c: i64 = 0;
        while c < a.shape.cols {
            acc = f32_add(acc, f32_mul(tensor_f32_at(a, r, c), tensor_f32_at(x, c, 0)));
            c = c + 1;
        };
        data.push(acc);
        r = r + 1;
    };
    return tensor_f32_from_vec(a.shape.rows, 1, data);
}

fn tensor_f32_broadcast_add_row(a: &TensorF32, row: &TensorF32) -> TensorF32 {
    if row.shape.rows != 1 {
        print("broadcast error: right tensor must have one row");
        return tensor_f32_zeros(0, 0);
    };
    if row.shape.cols != a.shape.cols {
        print("broadcast error: right cols must equal left cols");
        return tensor_f32_zeros(0, 0);
    };
    let mut data: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < a.shape.rows {
        let mut c: i64 = 0;
        while c < a.shape.cols {
            data.push(f32_add(tensor_f32_at(a, r, c), tensor_f32_at(row, 0, c)));
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f32_from_vec(a.shape.rows, a.shape.cols, data);
}

fn tensor_f32_reduce_axis0(a: &TensorF32) -> TensorF32 {
    let mut data: Vec<i64> = Vec::new();
    let mut c: i64 = 0;
    while c < a.shape.cols {
        let mut acc: i64 = f32_from_int(0);
        let mut r: i64 = 0;
        while r < a.shape.rows {
            acc = f32_add(acc, tensor_f32_at(a, r, c));
            r = r + 1;
        };
        data.push(acc);
        c = c + 1;
    };
    return tensor_f32_from_vec(1, a.shape.cols, data);
}

fn tensor_f32_reduce_axis1(a: &TensorF32) -> TensorF32 {
    let mut data: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < a.shape.rows {
        let mut acc: i64 = f32_from_int(0);
        let mut c: i64 = 0;
        while c < a.shape.cols {
            acc = f32_add(acc, tensor_f32_at(a, r, c));
            c = c + 1;
        };
        data.push(acc);
        r = r + 1;
    };
    return tensor_f32_from_vec(a.shape.rows, 1, data);
}

fn tensor_f64_reduce_axis0(a: &TensorF64) -> TensorF64 {
    let mut data: Vec<f64> = Vec::new();
    let mut c: i64 = 0;
    while c < a.shape.cols {
        let mut acc: f64 = 0.0;
        let mut r: i64 = 0;
        while r < a.shape.rows {
            acc = acc + tensor_f64_at(a, r, c);
            r = r + 1;
        };
        data.push(acc);
        c = c + 1;
    };
    return tensor_f64_from_vec(1, a.shape.cols, data);
}

fn tensor_f64_reduce_axis1(a: &TensorF64) -> TensorF64 {
    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < a.shape.rows {
        let mut acc: f64 = 0.0;
        let mut c: i64 = 0;
        while c < a.shape.cols {
            acc = acc + tensor_f64_at(a, r, c);
            c = c + 1;
        };
        data.push(acc);
        r = r + 1;
    };
    return tensor_f64_from_vec(a.shape.rows, 1, data);
}

fn tensor_f64_mean_axis0(a: &TensorF64) -> TensorF64 {
    let sums: TensorF64 = tensor_f64_reduce_axis0(a);
    let mut data: Vec<f64> = Vec::new();
    let mut c: i64 = 0;
    while c < a.shape.cols {
        data.push(tensor_f64_at(&sums, 0, c) / (a.shape.rows as f64));
        c = c + 1;
    };
    return tensor_f64_from_vec(1, a.shape.cols, data);
}

fn tensor_f64_variance_axis0(a: &TensorF64, mean: &TensorF64) -> TensorF64 {
    if mean.shape.rows != 1 {
        print("variance error: mean must be a single row");
        return tensor_f64_zeros(0, 0);
    };
    if mean.shape.cols != a.shape.cols {
        print("variance error: mean cols must equal input cols");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut c: i64 = 0;
    while c < a.shape.cols {
        let mut acc: f64 = 0.0;
        let mut r: i64 = 0;
        while r < a.shape.rows {
            let d: f64 = tensor_f64_at(a, r, c) - tensor_f64_at(mean, 0, c);
            acc = acc + d * d;
            r = r + 1;
        };
        data.push(acc / (a.shape.rows as f64));
        c = c + 1;
    };
    return tensor_f64_from_vec(1, a.shape.cols, data);
}

fn tensor_f64_max_axis1(a: &TensorF64) -> TensorF64 {
    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < a.shape.rows {
        let mut c: i64 = 1;
        let mut best: f64 = tensor_f64_at(a, r, 0);
        while c < a.shape.cols {
            let value: f64 = tensor_f64_at(a, r, c);
            if value > best { best = value; };
            c = c + 1;
        };
        data.push(best);
        r = r + 1;
    };
    return tensor_f64_from_vec(a.shape.rows, 1, data);
}

fn tensor_f64_argmax_axis1(a: &TensorF64) -> TensorI64 {
    let mut data: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < a.shape.rows {
        let mut c: i64 = 1;
        let mut best_col: i64 = 0;
        let mut best: f64 = tensor_f64_at(a, r, 0);
        while c < a.shape.cols {
            let value: f64 = tensor_f64_at(a, r, c);
            if value > best {
                best = value;
                best_col = c;
            };
            c = c + 1;
        };
        data.push(best_col);
        r = r + 1;
    };
    return tensor_i64_from_vec(a.shape.rows, 1, data);
}

fn tensor_f64_print_metadata(label: str, t: &TensorF64) -> i64 {
    print(label);
    print("dtype:");
    print(dtype_name(t.dtype));
    print("accumulator:");
    print(dtype_name(t.accumulator_dtype));
    print("policy:");
    print(policy_name(t.policy));
    shape2_print("shape rows cols:", &t.shape);
    return 0;
}

fn tensor_f64_print_flat(label: str, t: &TensorF64) -> i64 {
    print(label);
    let mut i: i64 = 0;
    while i < tensor_f64_len(t) {
        print_f64(t.data[i]);
        i = i + 1;
    };
    return 0;
}

fn tensor_f32_print_metadata(label: str, t: &TensorF32) -> i64 {
    print(label);
    print("dtype:");
    print(dtype_name(t.dtype));
    print("accumulator:");
    print(dtype_name(t.accumulator_dtype));
    print("policy:");
    print(policy_name(t.policy));
    shape2_print("shape rows cols:", &t.shape);
    return 0;
}

fn tensor_f32_print_flat(label: str, t: &TensorF32) -> i64 {
    print(label);
    let mut i: i64 = 0;
    while i < tensor_f32_len(t) {
        print_f32(t.data[i]);
        i = i + 1;
    };
    return 0;
}

fn tensor_i64_print_flat(label: str, t: &TensorI64) -> i64 {
    print(label);
    let mut i: i64 = 0;
    while i < tensor_i64_len(t) {
        print_int(t.data[i]);
        i = i + 1;
    };
    return 0;
}
