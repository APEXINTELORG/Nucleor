// shape_core.nr - minimal shape contracts for the first tensor facade.

#[repr(C)]
struct Shape2 {
    rows: i64,
    cols: i64
}

fn shape2(rows: i64, cols: i64) -> Shape2 {
    return Shape2 { rows: rows, cols: cols };
}

fn shape2_total(shape: &Shape2) -> i64 {
    return shape.rows * shape.cols;
}

fn shape2_same(a: &Shape2, b: &Shape2) -> bool {
    if a.rows != b.rows { return false; };
    if a.cols != b.cols { return false; };
    return true;
}

fn shape2_can_matmul(a: &Shape2, b: &Shape2) -> bool {
    return a.cols == b.rows;
}

fn shape2_assert_same(a: &Shape2, b: &Shape2) -> i64 {
    if shape2_same(a, b) { return 0; };
    print("shape error: shapes are not equal");
    return 1;
}

fn shape2_assert_matmul(a: &Shape2, b: &Shape2) -> i64 {
    if shape2_can_matmul(a, b) { return 0; };
    print("shape error: left cols must equal right rows for matmul");
    return 1;
}

fn shape2_print(label: str, shape: &Shape2) -> i64 {
    print(label);
    print_int(shape.rows);
    print_int(shape.cols);
    return 0;
}
