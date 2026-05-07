// rods/ml/learn_facade — scikit-learn parity rods (linear, logistic, KNN, KMeans, PCA, NB, trees, SVM, encoders, splits, metrics)
//
import "stdlib/rods/ml/tensor_facade.nr"

// learn_facade.nr - first sklearn-style facade.
//
// This slice maps common Python estimator workflows onto explicit Nucleor
// tensor primitives with deterministic, auditable numerics.

#[repr(C)]
struct StandardScalerF64 {
    mean: TensorF64,
    scale: TensorF64
}

#[repr(C)]
struct MinMaxScalerF64 {
    scale: TensorF64,
    min: TensorF64
}

#[repr(C)]
struct MaxAbsScalerF64 {
    scale: TensorF64,
    max_abs: TensorF64
}

#[repr(C)]
struct SimpleImputerF64 {
    statistics: TensorF64
}

#[repr(C)]
struct OneHotEncoderI64 {
    categories: TensorI64
}

#[repr(C)]
struct LabelEncoderI64 {
    classes: TensorI64
}

#[repr(C)]
struct OrdinalEncoderI64 {
    categories: TensorI64,
    unknown_value: i64
}

#[repr(C)]
struct LinearModelF64 {
    weights: TensorF64,
    bias: f64
}

#[repr(C)]
struct LinearMultiOutputModelF64 {
    weights: TensorF64,
    bias: TensorF64
}

#[repr(C)]
struct LogisticBinaryModelF64 {
    weights: TensorF64,
    bias: f64,
    negative_class: i64,
    positive_class: i64
}

#[repr(C)]
struct LogisticMulticlassModelF64 {
    weights: TensorF64,
    bias: TensorF64,
    classes: TensorI64
}

#[repr(C)]
struct LinearSvcModelF64 {
    weights: TensorF64,
    bias: TensorF64,
    classes: TensorI64
}

#[repr(C)]
struct RbfSvcBinaryModelF64 {
    support_vectors: TensorF64,
    dual_coef: TensorF64,
    intercept: f64,
    gamma: f64,
    negative_class: i64,
    positive_class: i64
}

#[repr(C)]
struct DecisionTreeClassifierF64 {
    node_left_indices: Vec<i64>,
    node_right_indices: Vec<i64>,
    node_feature_indices: Vec<i64>,
    node_thresholds: Vec<f64>,
    node_values: TensorF64,
    classes: TensorI64
}

#[repr(C)]
struct ScalerLogisticBinaryPipelineF64 {
    scaler: StandardScalerF64,
    classifier: LogisticBinaryModelF64
}

#[repr(C)]
struct TrainTestSplitF64I64 {
    x_train: TensorF64,
    x_test: TensorF64,
    y_train: TensorI64,
    y_test: TensorI64
}

#[repr(C)]
struct TrainTestIndexSplit {
    train_indices: TensorI64,
    test_indices: TensorI64
}

#[repr(C)]
struct KFoldIndicesI64 {
    train_indices: TensorI64,
    test_indices: TensorI64
}

#[repr(C)]
struct KMeansF64 {
    centers: TensorF64
}

#[repr(C)]
struct PcaF64 {
    components: TensorF64,
    mean: TensorF64
}

#[repr(C)]
struct GaussianNBF64 {
    theta: TensorF64,
    var: TensorF64,
    class_prior: TensorF64,
    classes: TensorI64
}

#[repr(C)]
struct MultinomialNBF64 {
    feature_log_prob: TensorF64,
    class_log_prior: TensorF64,
    classes: TensorI64
}

#[repr(C)]
struct BernoulliNBF64 {
    feature_log_prob: TensorF64,
    class_log_prior: TensorF64,
    classes: TensorI64
}

#[repr(C)]
struct KnnClassifierF64 {
    x_train: TensorF64,
    y_train: TensorI64
}

#[repr(C)]
struct NearestNeighborsF64 {
    x_train: TensorF64
}

fn standard_scaler_f64(mean: TensorF64, scale: TensorF64) -> StandardScalerF64 {
    return StandardScalerF64 {
        mean: mean,
        scale: scale
    };
}

fn minmax_scaler_f64(scale: TensorF64, min: TensorF64) -> MinMaxScalerF64 {
    return MinMaxScalerF64 {
        scale: scale,
        min: min
    };
}

fn maxabs_scaler_f64(scale: TensorF64, max_abs: TensorF64) -> MaxAbsScalerF64 {
    return MaxAbsScalerF64 {
        scale: scale,
        max_abs: max_abs
    };
}

fn simple_imputer_f64(statistics: TensorF64) -> SimpleImputerF64 {
    return SimpleImputerF64 {
        statistics: statistics
    };
}

fn one_hot_encoder_i64(categories: TensorI64) -> OneHotEncoderI64 {
    return OneHotEncoderI64 {
        categories: categories
    };
}

fn label_encoder_i64(classes: TensorI64) -> LabelEncoderI64 {
    return LabelEncoderI64 {
        classes: classes
    };
}

fn ordinal_encoder_i64(categories: TensorI64, unknown_value: i64) -> OrdinalEncoderI64 {
    return OrdinalEncoderI64 {
        categories: categories,
        unknown_value: unknown_value
    };
}

fn learn_f64_sqrt_newton(x: f64) -> f64 {
    if x <= 0.0 { return 0.0; };
    let mut guess: f64 = x;
    if guess < 1.0 { guess = 1.0; };
    let mut i: i64 = 0;
    while i < 24 {
        guess = (guess + x / guess) * 0.5;
        i = i + 1;
    };
    return guess;
}

fn learn_exp_f64(x: f64) -> f64 {
    return exp(x);
}

fn learn_log_f64(x: f64) -> f64 {
    return log(x);
}

fn standard_scaler_f64_fit(x: &TensorF64) -> StandardScalerF64 {
    let mean: TensorF64 = tensor_f64_mean_axis0(x);
    let variance: TensorF64 = tensor_f64_variance_axis0(x, &mean);

    let mut scale_data: Vec<f64> = Vec::new();
    let mut c: i64 = 0;
    while c < variance.shape.cols {
        let mut scale: f64 = learn_f64_sqrt_newton(tensor_f64_at(&variance, 0, c));
        if scale == 0.0 { scale = 1.0; };
        scale_data.push(scale);
        c = c + 1;
    };
    let scale: TensorF64 = tensor_f64_from_vec(1, x.shape.cols, scale_data);
    return standard_scaler_f64(mean, scale);
}

fn minmax_scaler_f64_fit_range(x: &TensorF64, feature_min: f64, feature_max: f64) -> MinMaxScalerF64 {
    if x.shape.rows <= 0 || x.shape.cols <= 0 {
        print("learn error: MinMaxScaler fit input must be non-empty");
        return minmax_scaler_f64(tensor_f64_zeros(0, 0), tensor_f64_zeros(0, 0));
    };
    if feature_max <= feature_min {
        print("learn error: MinMaxScaler feature_max must be greater than feature_min");
        return minmax_scaler_f64(tensor_f64_zeros(0, 0), tensor_f64_zeros(0, 0));
    };

    let mut scale_data: Vec<f64> = Vec::new();
    let mut min_data: Vec<f64> = Vec::new();
    let mut c: i64 = 0;
    while c < x.shape.cols {
        let mut min_value: f64 = tensor_f64_at(x, 0, c);
        let mut max_value: f64 = min_value;
        let mut r: i64 = 1;
        while r < x.shape.rows {
            let value: f64 = tensor_f64_at(x, r, c);
            if value < min_value { min_value = value; };
            if value > max_value { max_value = value; };
            r = r + 1;
        };
        let mut data_range: f64 = max_value - min_value;
        if data_range == 0.0 { data_range = 1.0; };
        let scale_value: f64 = (feature_max - feature_min) / data_range;
        scale_data.push(scale_value);
        min_data.push(feature_min - min_value * scale_value);
        c = c + 1;
    };
    return minmax_scaler_f64(
        tensor_f64_from_vec(1, x.shape.cols, scale_data),
        tensor_f64_from_vec(1, x.shape.cols, min_data)
    );
}

fn maxabs_scaler_f64_fit(x: &TensorF64) -> MaxAbsScalerF64 {
    if x.shape.rows <= 0 || x.shape.cols <= 0 {
        print("learn error: MaxAbsScaler fit input must be non-empty");
        return maxabs_scaler_f64(tensor_f64_zeros(0, 0), tensor_f64_zeros(0, 0));
    };

    let mut scale_data: Vec<f64> = Vec::new();
    let mut max_abs_data: Vec<f64> = Vec::new();
    let mut c: i64 = 0;
    while c < x.shape.cols {
        let mut max_abs_value: f64 = 0.0;
        let mut r: i64 = 0;
        while r < x.shape.rows {
            let mut value: f64 = tensor_f64_at(x, r, c);
            if value < 0.0 { value = 0.0 - value; };
            if value > max_abs_value { max_abs_value = value; };
            r = r + 1;
        };
        max_abs_data.push(max_abs_value);
        if max_abs_value == 0.0 {
            scale_data.push(1.0);
        } else {
            scale_data.push(max_abs_value);
        };
        c = c + 1;
    };
    return maxabs_scaler_f64(
        tensor_f64_from_vec(1, x.shape.cols, scale_data),
        tensor_f64_from_vec(1, x.shape.cols, max_abs_data)
    );
}

fn simple_imputer_mean_f64_fit(x: &TensorF64, missing_mask: &TensorI64) -> SimpleImputerF64 {
    if x.shape.rows <= 0 || x.shape.cols <= 0 {
        print("learn error: SimpleImputer fit input must be non-empty");
        return simple_imputer_f64(tensor_f64_zeros(0, 0));
    };
    if missing_mask.shape.rows != x.shape.rows || missing_mask.shape.cols != x.shape.cols {
        print("learn error: SimpleImputer missing mask shape must equal input shape");
        return simple_imputer_f64(tensor_f64_zeros(0, 0));
    };

    let mut stats: Vec<f64> = Vec::new();
    let mut c: i64 = 0;
    while c < x.shape.cols {
        let mut acc: f64 = 0.0;
        let mut count: i64 = 0;
        let mut r: i64 = 0;
        while r < x.shape.rows {
            if tensor_i64_at(missing_mask, r, c) == 0 {
                acc = acc + tensor_f64_at(x, r, c);
                count = count + 1;
            };
            r = r + 1;
        };
        if count <= 0 {
            print("learn error: SimpleImputer mean requires at least one observed value per column");
            return simple_imputer_f64(tensor_f64_zeros(0, 0));
        };
        stats.push(acc / (count as f64));
        c = c + 1;
    };
    return simple_imputer_f64(tensor_f64_from_vec(1, x.shape.cols, stats));
}

fn simple_imputer_transform_f64(imputer: &SimpleImputerF64, x: &TensorF64, missing_mask: &TensorI64) -> TensorF64 {
    if imputer.statistics.shape.rows != 1 || imputer.statistics.shape.cols != x.shape.cols {
        print("learn error: SimpleImputer statistics must be one row matching input cols");
        return tensor_f64_zeros(0, 0);
    };
    if missing_mask.shape.rows != x.shape.rows || missing_mask.shape.cols != x.shape.cols {
        print("learn error: SimpleImputer missing mask shape must equal input shape");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut c: i64 = 0;
        while c < x.shape.cols {
            if tensor_i64_at(missing_mask, r, c) != 0 {
                data.push(tensor_f64_at(&imputer.statistics, 0, c));
            } else {
                data.push(tensor_f64_at(x, r, c));
            };
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, x.shape.cols, data);
}

fn simple_imputer_mean_f64_fit_transform(x: &TensorF64, missing_mask: &TensorI64) -> TensorF64 {
    let imputer: SimpleImputerF64 = simple_imputer_mean_f64_fit(x, missing_mask);
    return simple_imputer_transform_f64(&imputer, x, missing_mask);
}

fn normalizer_l2_f64_transform(x: &TensorF64) -> TensorF64 {
    if x.shape.rows <= 0 || x.shape.cols <= 0 {
        print("learn error: Normalizer input must be non-empty");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut sq_sum: f64 = 0.0;
        let mut c: i64 = 0;
        while c < x.shape.cols {
            let value: f64 = tensor_f64_at(x, r, c);
            sq_sum = sq_sum + value * value;
            c = c + 1;
        };
        let norm: f64 = learn_f64_sqrt_newton(sq_sum);
        c = 0;
        while c < x.shape.cols {
            let value: f64 = tensor_f64_at(x, r, c);
            if norm > 0.0 {
                data.push(value / norm);
            } else {
                data.push(value);
            };
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, x.shape.cols, data);
}

fn binarizer_f64_transform(x: &TensorF64, threshold: f64) -> TensorF64 {
    if x.shape.rows <= 0 || x.shape.cols <= 0 {
        print("learn error: Binarizer input must be non-empty");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut c: i64 = 0;
        while c < x.shape.cols {
            if tensor_f64_at(x, r, c) > threshold {
                data.push(1.0);
            } else {
                data.push(0.0);
            };
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, x.shape.cols, data);
}

fn train_test_split_f64_i64_indices(x: &TensorF64, y: &TensorI64, train_indices: &TensorI64, test_indices: &TensorI64) -> TrainTestSplitF64I64 {
    if x.shape.rows != y.shape.rows {
        print("learn error: train/test split x and y rows must match");
        return TrainTestSplitF64I64 {
            x_train: tensor_f64_zeros(0, 0),
            x_test: tensor_f64_zeros(0, 0),
            y_train: tensor_i64_zeros(0, 0),
            y_test: tensor_i64_zeros(0, 0)
        };
    };
    return TrainTestSplitF64I64 {
        x_train: tensor_f64_select_rows(x, train_indices),
        x_test: tensor_f64_select_rows(x, test_indices),
        y_train: tensor_i64_select_rows(y, train_indices),
        y_test: tensor_i64_select_rows(y, test_indices)
    };
}

fn learn_lcg_next(state: i64) -> i64 {
    let m: i64 = 2147483648;
    let next: i64 = (state * 1103515245 + 12345) % m;
    if next < 0 { return next + m; };
    return next;
}

fn train_test_split_indices_seeded(row_count: i64, test_count: i64, seed: i64) -> TrainTestIndexSplit {
    if row_count < 0 {
        print("learn error: row_count must be non-negative");
        return TrainTestIndexSplit {
            train_indices: tensor_i64_zeros(0, 0),
            test_indices: tensor_i64_zeros(0, 0)
        };
    };
    if test_count < 0 || test_count > row_count {
        print("learn error: test_count must be between zero and row_count");
        return TrainTestIndexSplit {
            train_indices: tensor_i64_zeros(0, 0),
            test_indices: tensor_i64_zeros(0, 0)
        };
    };

    let mut idx: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < row_count {
        idx.push(i);
        i = i + 1;
    };

    let mut state: i64 = seed;
    i = row_count - 1;
    while i > 0 {
        state = learn_lcg_next(state);
        let j: i64 = state % (i + 1);
        let tmp: i64 = idx[i];
        vec_set(idx, i, idx[j]);
        vec_set(idx, j, tmp);
        i = i - 1;
    };

    let mut train: Vec<i64> = Vec::new();
    let mut test: Vec<i64> = Vec::new();
    i = 0;
    while i < row_count {
        if i < test_count {
            test.push(idx[i]);
        } else {
            train.push(idx[i]);
        };
        i = i + 1;
    };

    return TrainTestIndexSplit {
        train_indices: tensor_i64_from_vec(row_count - test_count, 1, train),
        test_indices: tensor_i64_from_vec(test_count, 1, test)
    };
}

fn kfold_indices_i64_empty() -> KFoldIndicesI64 {
    return KFoldIndicesI64 {
        train_indices: tensor_i64_zeros(0, 0),
        test_indices: tensor_i64_zeros(0, 0)
    };
}

fn kfold_indices_i64(row_count: i64, fold_count: i64) -> KFoldIndicesI64 {
    if row_count <= 0 {
        print("learn error: KFold row_count must be positive");
        return kfold_indices_i64_empty();
    };
    if fold_count <= 1 || fold_count > row_count {
        print("learn error: KFold fold_count must be between two and row_count");
        return kfold_indices_i64_empty();
    };
    if row_count % fold_count != 0 {
        print("learn error: KFold first pass requires equal fold sizes");
        return kfold_indices_i64_empty();
    };

    let test_count: i64 = row_count / fold_count;
    let train_count: i64 = row_count - test_count;
    let mut train: Vec<i64> = Vec::new();
    let mut test: Vec<i64> = Vec::new();
    let mut fold: i64 = 0;
    while fold < fold_count {
        let test_start: i64 = fold * test_count;
        let test_end: i64 = test_start + test_count;
        let mut i: i64 = 0;
        while i < row_count {
            if i >= test_start && i < test_end {
                test.push(i);
            } else {
                train.push(i);
            };
            i = i + 1;
        };
        fold = fold + 1;
    };

    return KFoldIndicesI64 {
        train_indices: tensor_i64_from_vec(fold_count, train_count, train),
        test_indices: tensor_i64_from_vec(fold_count, test_count, test)
    };
}

fn leave_one_out_indices_i64(row_count: i64) -> KFoldIndicesI64 {
    if row_count <= 1 {
        print("learn error: LeaveOneOut row_count must be greater than one");
        return kfold_indices_i64_empty();
    };

    let mut train: Vec<i64> = Vec::new();
    let mut test: Vec<i64> = Vec::new();
    let mut fold: i64 = 0;
    while fold < row_count {
        let mut i: i64 = 0;
        while i < row_count {
            if i == fold {
                test.push(i);
            } else {
                train.push(i);
            };
            i = i + 1;
        };
        fold = fold + 1;
    };

    return KFoldIndicesI64 {
        train_indices: tensor_i64_from_vec(row_count, row_count - 1, train),
        test_indices: tensor_i64_from_vec(row_count, 1, test)
    };
}

fn learn_class_index_i64(classes: &TensorI64, value: i64) -> i64 {
    let mut c: i64 = 0;
    while c < tensor_i64_len(classes) {
        if classes.data[c] == value {
            return c;
        };
        c = c + 1;
    };
    return -1;
}

fn stratified_kfold_indices_i64(y: &TensorI64, classes: &TensorI64, fold_count: i64) -> KFoldIndicesI64 {
    if y.shape.cols != 1 {
        print("learn error: StratifiedKFold labels must be a single column");
        return kfold_indices_i64_empty();
    };
    if fold_count <= 1 || fold_count > y.shape.rows {
        print("learn error: StratifiedKFold fold_count must be between two and row_count");
        return kfold_indices_i64_empty();
    };
    let class_count: i64 = tensor_i64_len(classes);
    if class_count <= 0 {
        print("learn error: StratifiedKFold classes must be non-empty");
        return kfold_indices_i64_empty();
    };

    let mut counts: Vec<i64> = Vec::new();
    let mut c: i64 = 0;
    while c < class_count {
        counts.push(0);
        c = c + 1;
    };

    let mut i: i64 = 0;
    while i < tensor_i64_len(y) {
        let class_index: i64 = learn_class_index_i64(classes, y.data[i]);
        if class_index < 0 {
            print("learn error: StratifiedKFold saw label outside classes");
            return kfold_indices_i64_empty();
        };
        vec_set(counts, class_index, counts[class_index] + 1);
        i = i + 1;
    };

    c = 0;
    while c < class_count {
        if counts[c] < fold_count || counts[c] % fold_count != 0 {
            print("learn error: StratifiedKFold first pass requires each class count divisible by fold_count");
            return kfold_indices_i64_empty();
        };
        c = c + 1;
    };

    let test_count: i64 = y.shape.rows / fold_count;
    let train_count: i64 = y.shape.rows - test_count;
    let mut train: Vec<i64> = Vec::new();
    let mut test: Vec<i64> = Vec::new();
    let mut fold: i64 = 0;
    while fold < fold_count {
        let mut seen: Vec<i64> = Vec::new();
        c = 0;
        while c < class_count {
            seen.push(0);
            c = c + 1;
        };

        i = 0;
        while i < y.shape.rows {
            let class_index: i64 = learn_class_index_i64(classes, tensor_i64_at(y, i, 0));
            let occurrence_index: i64 = seen[class_index];
            vec_set(seen, class_index, occurrence_index + 1);
            if occurrence_index % fold_count == fold {
                test.push(i);
            } else {
                train.push(i);
            };
            i = i + 1;
        };
        fold = fold + 1;
    };

    return KFoldIndicesI64 {
        train_indices: tensor_i64_from_vec(fold_count, train_count, train),
        test_indices: tensor_i64_from_vec(fold_count, test_count, test)
    };
}

fn group_kfold_indices_i64(groups: &TensorI64, fold_count: i64) -> KFoldIndicesI64 {
    if groups.shape.cols != 1 {
        print("learn error: GroupKFold groups must be a single column");
        return kfold_indices_i64_empty();
    };
    if groups.shape.rows <= 0 {
        print("learn error: GroupKFold groups must be non-empty");
        return kfold_indices_i64_empty();
    };
    if fold_count <= 1 {
        print("learn error: GroupKFold fold_count must be greater than one");
        return kfold_indices_i64_empty();
    };
    if groups.shape.rows % fold_count != 0 {
        print("learn error: GroupKFold first pass requires equal fold sizes");
        return kfold_indices_i64_empty();
    };

    let mut unique_groups: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < groups.shape.rows {
        let value: i64 = tensor_i64_at(groups, r, 0);
        let mut found: i64 = 0;
        let mut u: i64 = 0;
        while u < vec_len(unique_groups) {
            if unique_groups[u] == value {
                found = 1;
            };
            u = u + 1;
        };
        if found == 0 {
            unique_groups.push(value);
        };
        r = r + 1;
    };

    let group_count: i64 = vec_len(unique_groups);
    if fold_count > group_count {
        print("learn error: GroupKFold fold_count must not exceed group count");
        return kfold_indices_i64_empty();
    };

    let mut a: i64 = 0;
    while a < group_count {
        let mut b: i64 = a + 1;
        while b < group_count {
            if unique_groups[b] < unique_groups[a] {
                let tmp: i64 = unique_groups[a];
                vec_set(unique_groups, a, unique_groups[b]);
                vec_set(unique_groups, b, tmp);
            };
            b = b + 1;
        };
        a = a + 1;
    };

    let mut counts: Vec<i64> = Vec::new();
    let mut group_order: Vec<i64> = Vec::new();
    let mut row_group_indices: Vec<i64> = Vec::new();
    let mut g: i64 = 0;
    while g < group_count {
        counts.push(0);
        group_order.push(g);
        g = g + 1;
    };

    r = 0;
    while r < groups.shape.rows {
        let value: i64 = tensor_i64_at(groups, r, 0);
        let mut group_index: i64 = -1;
        g = 0;
        while g < group_count {
            if unique_groups[g] == value {
                group_index = g;
            };
            g = g + 1;
        };
        if group_index < 0 {
            print("learn error: GroupKFold failed to resolve group index");
            return kfold_indices_i64_empty();
        };
        row_group_indices.push(group_index);
        vec_set(counts, group_index, counts[group_index] + 1);
        r = r + 1;
    };

    a = 0;
    while a < group_count {
        let mut b2: i64 = a + 1;
        while b2 < group_count {
            let left: i64 = group_order[a];
            let right: i64 = group_order[b2];
            if counts[right] > counts[left] || (counts[right] == counts[left] && right > left) {
                vec_set(group_order, a, right);
                vec_set(group_order, b2, left);
            };
            b2 = b2 + 1;
        };
        a = a + 1;
    };

    let mut fold_loads: Vec<i64> = Vec::new();
    let mut group_to_fold: Vec<i64> = Vec::new();
    let mut fold: i64 = 0;
    while fold < fold_count {
        fold_loads.push(0);
        fold = fold + 1;
    };
    g = 0;
    while g < group_count {
        group_to_fold.push(0);
        g = g + 1;
    };

    let mut order_pos: i64 = 0;
    while order_pos < group_count {
        let group_index: i64 = group_order[order_pos];
        let mut lightest_fold: i64 = 0;
        fold = 1;
        while fold < fold_count {
            if fold_loads[fold] < fold_loads[lightest_fold] {
                lightest_fold = fold;
            };
            fold = fold + 1;
        };
        vec_set(group_to_fold, group_index, lightest_fold);
        vec_set(fold_loads, lightest_fold, fold_loads[lightest_fold] + counts[group_index]);
        order_pos = order_pos + 1;
    };

    let test_count: i64 = groups.shape.rows / fold_count;
    fold = 0;
    while fold < fold_count {
        if fold_loads[fold] != test_count {
            print("learn error: GroupKFold first pass requires balanced group fold sizes");
            return kfold_indices_i64_empty();
        };
        fold = fold + 1;
    };

    let train_count: i64 = groups.shape.rows - test_count;
    let mut train: Vec<i64> = Vec::new();
    let mut test: Vec<i64> = Vec::new();
    fold = 0;
    while fold < fold_count {
        r = 0;
        while r < groups.shape.rows {
            let row_group_index: i64 = row_group_indices[r];
            if group_to_fold[row_group_index] == fold {
                test.push(r);
            } else {
                train.push(r);
            };
            r = r + 1;
        };
        fold = fold + 1;
    };

    return KFoldIndicesI64 {
        train_indices: tensor_i64_from_vec(fold_count, train_count, train),
        test_indices: tensor_i64_from_vec(fold_count, test_count, test)
    };
}

fn linear_model_f64(weights: TensorF64, bias: f64) -> LinearModelF64 {
    return LinearModelF64 {
        weights: weights,
        bias: bias
    };
}

fn linear_multioutput_model_f64(weights: TensorF64, bias: TensorF64) -> LinearMultiOutputModelF64 {
    return LinearMultiOutputModelF64 {
        weights: weights,
        bias: bias
    };
}

fn logistic_binary_model_f64(weights: TensorF64, bias: f64, negative_class: i64, positive_class: i64) -> LogisticBinaryModelF64 {
    return LogisticBinaryModelF64 {
        weights: weights,
        bias: bias,
        negative_class: negative_class,
        positive_class: positive_class
    };
}

fn logistic_multiclass_model_f64(weights: TensorF64, bias: TensorF64, classes: TensorI64) -> LogisticMulticlassModelF64 {
    return LogisticMulticlassModelF64 {
        weights: weights,
        bias: bias,
        classes: classes
    };
}

fn linear_svc_model_f64(weights: TensorF64, bias: TensorF64, classes: TensorI64) -> LinearSvcModelF64 {
    return LinearSvcModelF64 {
        weights: weights,
        bias: bias,
        classes: classes
    };
}

fn rbf_svc_binary_model_f64(support_vectors: TensorF64, dual_coef: TensorF64, intercept: f64, gamma: f64, negative_class: i64, positive_class: i64) -> RbfSvcBinaryModelF64 {
    return RbfSvcBinaryModelF64 {
        support_vectors: support_vectors,
        dual_coef: dual_coef,
        intercept: intercept,
        gamma: gamma,
        negative_class: negative_class,
        positive_class: positive_class
    };
}

fn decision_tree_classifier_f64(
    node_left_indices: Vec<i64>,
    node_right_indices: Vec<i64>,
    node_feature_indices: Vec<i64>,
    node_thresholds: Vec<f64>,
    node_values: TensorF64,
    classes: TensorI64
) -> DecisionTreeClassifierF64 {
    return DecisionTreeClassifierF64 {
        node_left_indices: node_left_indices,
        node_right_indices: node_right_indices,
        node_feature_indices: node_feature_indices,
        node_thresholds: node_thresholds,
        node_values: node_values,
        classes: classes
    };
}

fn scaler_logistic_binary_pipeline_f64(scaler: StandardScalerF64, classifier: LogisticBinaryModelF64) -> ScalerLogisticBinaryPipelineF64 {
    return ScalerLogisticBinaryPipelineF64 {
        scaler: scaler,
        classifier: classifier
    };
}

fn kmeans_f64(centers: TensorF64) -> KMeansF64 {
    return KMeansF64 {
        centers: centers
    };
}

fn pca_f64(components: TensorF64, mean: TensorF64) -> PcaF64 {
    return PcaF64 {
        components: components,
        mean: mean
    };
}

fn gaussian_nb_f64(theta: TensorF64, var: TensorF64, class_prior: TensorF64, classes: TensorI64) -> GaussianNBF64 {
    return GaussianNBF64 {
        theta: theta,
        var: var,
        class_prior: class_prior,
        classes: classes
    };
}

fn multinomial_nb_f64(feature_log_prob: TensorF64, class_log_prior: TensorF64, classes: TensorI64) -> MultinomialNBF64 {
    return MultinomialNBF64 {
        feature_log_prob: feature_log_prob,
        class_log_prior: class_log_prior,
        classes: classes
    };
}

fn bernoulli_nb_f64(feature_log_prob: TensorF64, class_log_prior: TensorF64, classes: TensorI64) -> BernoulliNBF64 {
    return BernoulliNBF64 {
        feature_log_prob: feature_log_prob,
        class_log_prior: class_log_prior,
        classes: classes
    };
}

fn knn_classifier_f64(x_train: TensorF64, y_train: TensorI64) -> KnnClassifierF64 {
    return KnnClassifierF64 {
        x_train: x_train,
        y_train: y_train
    };
}

fn nearest_neighbors_f64(x_train: TensorF64) -> NearestNeighborsF64 {
    return NearestNeighborsF64 {
        x_train: x_train
    };
}

fn standard_scaler_f64_transform(scaler: &StandardScalerF64, x: &TensorF64) -> TensorF64 {
    if scaler.mean.shape.rows != 1 {
        print("learn error: scaler mean must be a single row");
        return tensor_f64_zeros(0, 0);
    };
    if scaler.scale.shape.rows != 1 {
        print("learn error: scaler scale must be a single row");
        return tensor_f64_zeros(0, 0);
    };
    if scaler.mean.shape.cols != x.shape.cols {
        print("learn error: scaler mean cols must equal input cols");
        return tensor_f64_zeros(0, 0);
    };
    if scaler.scale.shape.cols != x.shape.cols {
        print("learn error: scaler scale cols must equal input cols");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut c: i64 = 0;
        while c < x.shape.cols {
            let denom: f64 = tensor_f64_at(&scaler.scale, 0, c);
            if denom == 0.0 {
                print("learn error: scaler scale contains zero");
                return tensor_f64_zeros(0, 0);
            };
            data.push((tensor_f64_at(x, r, c) - tensor_f64_at(&scaler.mean, 0, c)) / denom);
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, x.shape.cols, data);
}

fn standard_scaler_f64_inverse_transform(scaler: &StandardScalerF64, x: &TensorF64) -> TensorF64 {
    if scaler.mean.shape.rows != 1 {
        print("learn error: scaler mean must be a single row");
        return tensor_f64_zeros(0, 0);
    };
    if scaler.scale.shape.rows != 1 {
        print("learn error: scaler scale must be a single row");
        return tensor_f64_zeros(0, 0);
    };
    if scaler.mean.shape.cols != x.shape.cols {
        print("learn error: scaler mean cols must equal input cols");
        return tensor_f64_zeros(0, 0);
    };
    if scaler.scale.shape.cols != x.shape.cols {
        print("learn error: scaler scale cols must equal input cols");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut c: i64 = 0;
        while c < x.shape.cols {
            data.push(tensor_f64_at(x, r, c) * tensor_f64_at(&scaler.scale, 0, c) + tensor_f64_at(&scaler.mean, 0, c));
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, x.shape.cols, data);
}

fn minmax_scaler_f64_transform(scaler: &MinMaxScalerF64, x: &TensorF64) -> TensorF64 {
    if scaler.scale.shape.rows != 1 || scaler.min.shape.rows != 1 {
        print("learn error: MinMaxScaler scale and min must be single-row tensors");
        return tensor_f64_zeros(0, 0);
    };
    if scaler.scale.shape.cols != x.shape.cols || scaler.min.shape.cols != x.shape.cols {
        print("learn error: MinMaxScaler metadata cols must equal input cols");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut c: i64 = 0;
        while c < x.shape.cols {
            data.push(tensor_f64_at(x, r, c) * tensor_f64_at(&scaler.scale, 0, c) + tensor_f64_at(&scaler.min, 0, c));
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, x.shape.cols, data);
}

fn minmax_scaler_f64_inverse_transform(scaler: &MinMaxScalerF64, x: &TensorF64) -> TensorF64 {
    if scaler.scale.shape.rows != 1 || scaler.min.shape.rows != 1 {
        print("learn error: MinMaxScaler scale and min must be single-row tensors");
        return tensor_f64_zeros(0, 0);
    };
    if scaler.scale.shape.cols != x.shape.cols || scaler.min.shape.cols != x.shape.cols {
        print("learn error: MinMaxScaler metadata cols must equal input cols");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut c: i64 = 0;
        while c < x.shape.cols {
            let scale_value: f64 = tensor_f64_at(&scaler.scale, 0, c);
            if scale_value == 0.0 {
                print("learn error: MinMaxScaler scale contains zero");
                return tensor_f64_zeros(0, 0);
            };
            data.push((tensor_f64_at(x, r, c) - tensor_f64_at(&scaler.min, 0, c)) / scale_value);
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, x.shape.cols, data);
}

fn maxabs_scaler_f64_transform(scaler: &MaxAbsScalerF64, x: &TensorF64) -> TensorF64 {
    if scaler.scale.shape.rows != 1 {
        print("learn error: MaxAbsScaler scale must be a single-row tensor");
        return tensor_f64_zeros(0, 0);
    };
    if scaler.scale.shape.cols != x.shape.cols {
        print("learn error: MaxAbsScaler metadata cols must equal input cols");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut c: i64 = 0;
        while c < x.shape.cols {
            data.push(tensor_f64_at(x, r, c) / tensor_f64_at(&scaler.scale, 0, c));
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, x.shape.cols, data);
}

fn maxabs_scaler_f64_inverse_transform(scaler: &MaxAbsScalerF64, x: &TensorF64) -> TensorF64 {
    if scaler.scale.shape.rows != 1 {
        print("learn error: MaxAbsScaler scale must be a single-row tensor");
        return tensor_f64_zeros(0, 0);
    };
    if scaler.scale.shape.cols != x.shape.cols {
        print("learn error: MaxAbsScaler metadata cols must equal input cols");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut c: i64 = 0;
        while c < x.shape.cols {
            data.push(tensor_f64_at(x, r, c) * tensor_f64_at(&scaler.scale, 0, c));
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, x.shape.cols, data);
}

fn polynomial_features_degree2_f64(x: &TensorF64, include_bias: i64) -> TensorF64 {
    if x.shape.cols <= 0 {
        print("learn error: PolynomialFeatures requires at least one input column");
        return tensor_f64_zeros(0, 0);
    };

    let mut out_cols: i64 = x.shape.cols + (x.shape.cols * (x.shape.cols + 1)) / 2;
    if include_bias != 0 {
        out_cols = out_cols + 1;
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        if include_bias != 0 {
            data.push(1.0);
        };
        let mut c: i64 = 0;
        while c < x.shape.cols {
            data.push(tensor_f64_at(x, r, c));
            c = c + 1;
        };
        let mut a: i64 = 0;
        while a < x.shape.cols {
            let mut b: i64 = a;
            while b < x.shape.cols {
                data.push(tensor_f64_at(x, r, a) * tensor_f64_at(x, r, b));
                b = b + 1;
            };
            a = a + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, out_cols, data);
}

fn polynomial_features_degree3_f64(x: &TensorF64, include_bias: i64) -> TensorF64 {
    if x.shape.cols <= 0 {
        print("learn error: PolynomialFeatures requires at least one input column");
        return tensor_f64_zeros(0, 0);
    };

    let degree2_cols: i64 = (x.shape.cols * (x.shape.cols + 1)) / 2;
    let degree3_cols: i64 = (x.shape.cols * (x.shape.cols + 1) * (x.shape.cols + 2)) / 6;
    let mut out_cols: i64 = x.shape.cols + degree2_cols + degree3_cols;
    if include_bias != 0 {
        out_cols = out_cols + 1;
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        if include_bias != 0 {
            data.push(1.0);
        };
        let mut c: i64 = 0;
        while c < x.shape.cols {
            data.push(tensor_f64_at(x, r, c));
            c = c + 1;
        };
        let mut a: i64 = 0;
        while a < x.shape.cols {
            let mut b: i64 = a;
            while b < x.shape.cols {
                data.push(tensor_f64_at(x, r, a) * tensor_f64_at(x, r, b));
                b = b + 1;
            };
            a = a + 1;
        };
        a = 0;
        while a < x.shape.cols {
            let mut b: i64 = a;
            while b < x.shape.cols {
                let mut c3: i64 = b;
                while c3 < x.shape.cols {
                    data.push(tensor_f64_at(x, r, a) * tensor_f64_at(x, r, b) * tensor_f64_at(x, r, c3));
                    c3 = c3 + 1;
                };
                b = b + 1;
            };
            a = a + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, out_cols, data);
}

fn one_hot_encoder_i64_category_index(encoder: &OneHotEncoderI64, value: i64) -> i64 {
    let mut i: i64 = 0;
    while i < tensor_i64_len(&encoder.categories) {
        if encoder.categories.data[i] == value {
            return i;
        };
        i = i + 1;
    };
    return -1;
}

fn one_hot_encoder_i64_transform(encoder: &OneHotEncoderI64, x: &TensorI64) -> TensorF64 {
    let category_count: i64 = tensor_i64_len(&encoder.categories);
    if category_count <= 0 {
        print("learn error: OneHotEncoder categories must be non-empty");
        return tensor_f64_zeros(0, 0);
    };
    if x.shape.cols != 1 {
        print("learn error: OneHotEncoder first pass expects one categorical column");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let value: i64 = tensor_i64_at(x, r, 0);
        let category_index: i64 = one_hot_encoder_i64_category_index(encoder, value);
        let mut c: i64 = 0;
        while c < category_count {
            if c == category_index {
                data.push(1.0);
            } else {
                data.push(0.0);
            };
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, category_count, data);
}

fn column_transformer_numeric_onehot_f64_i64(numeric: &TensorF64, categorical: &TensorI64, encoder: &OneHotEncoderI64) -> TensorF64 {
    if numeric.shape.rows != categorical.shape.rows {
        print("learn error: ColumnTransformer numeric and categorical rows must match");
        return tensor_f64_zeros(0, 0);
    };

    let encoded: TensorF64 = one_hot_encoder_i64_transform(encoder, categorical);
    if encoded.shape.rows != numeric.shape.rows {
        return tensor_f64_zeros(0, 0);
    };

    let out_cols: i64 = numeric.shape.cols + encoded.shape.cols;
    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < numeric.shape.rows {
        let mut c: i64 = 0;
        while c < numeric.shape.cols {
            data.push(tensor_f64_at(numeric, r, c));
            c = c + 1;
        };

        c = 0;
        while c < encoded.shape.cols {
            data.push(tensor_f64_at(&encoded, r, c));
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(numeric.shape.rows, out_cols, data);
}

fn label_encoder_i64_class_index(encoder: &LabelEncoderI64, value: i64) -> i64 {
    let mut i: i64 = 0;
    while i < tensor_i64_len(&encoder.classes) {
        if encoder.classes.data[i] == value {
            return i;
        };
        i = i + 1;
    };
    return -1;
}

fn label_encoder_i64_transform(encoder: &LabelEncoderI64, y: &TensorI64) -> TensorI64 {
    let class_count: i64 = tensor_i64_len(&encoder.classes);
    if class_count <= 0 {
        print("learn error: LabelEncoder classes must be non-empty");
        return tensor_i64_zeros(0, 0);
    };

    let mut data: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_i64_len(y) {
        let encoded: i64 = label_encoder_i64_class_index(encoder, y.data[i]);
        if encoded < 0 {
            print("learn error: LabelEncoder saw unknown class");
            return tensor_i64_zeros(0, 0);
        };
        data.push(encoded);
        i = i + 1;
    };
    return tensor_i64_from_vec(y.shape.rows, y.shape.cols, data);
}

fn label_encoder_i64_inverse_transform(encoder: &LabelEncoderI64, y: &TensorI64) -> TensorI64 {
    let class_count: i64 = tensor_i64_len(&encoder.classes);
    if class_count <= 0 {
        print("learn error: LabelEncoder classes must be non-empty");
        return tensor_i64_zeros(0, 0);
    };

    let mut data: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_i64_len(y) {
        let encoded: i64 = y.data[i];
        if encoded < 0 || encoded >= class_count {
            print("learn error: LabelEncoder inverse index out of range");
            return tensor_i64_zeros(0, 0);
        };
        data.push(encoder.classes.data[encoded]);
        i = i + 1;
    };
    return tensor_i64_from_vec(y.shape.rows, y.shape.cols, data);
}

fn ordinal_encoder_i64_category_index(encoder: &OrdinalEncoderI64, value: i64) -> i64 {
    let mut i: i64 = 0;
    while i < tensor_i64_len(&encoder.categories) {
        if encoder.categories.data[i] == value {
            return i;
        };
        i = i + 1;
    };
    return -1;
}

fn ordinal_encoder_i64_transform(encoder: &OrdinalEncoderI64, x: &TensorI64) -> TensorI64 {
    let category_count: i64 = tensor_i64_len(&encoder.categories);
    if category_count <= 0 {
        print("learn error: OrdinalEncoder categories must be non-empty");
        return tensor_i64_zeros(0, 0);
    };
    if x.shape.cols != 1 {
        print("learn error: OrdinalEncoder first pass expects one categorical column");
        return tensor_i64_zeros(0, 0);
    };

    let mut data: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_i64_len(x) {
        let encoded: i64 = ordinal_encoder_i64_category_index(encoder, x.data[i]);
        if encoded < 0 {
            data.push(encoder.unknown_value);
        } else {
            data.push(encoded);
        };
        i = i + 1;
    };
    return tensor_i64_from_vec(x.shape.rows, x.shape.cols, data);
}

fn linear_model_f64_predict(model: &LinearModelF64, x: &TensorF64) -> TensorF64 {
    if model.weights.shape.cols != 1 {
        print("learn error: linear weights must be a single-column tensor");
        return tensor_f64_zeros(0, 0);
    };
    if x.shape.cols != model.weights.shape.rows {
        print("learn error: input cols must equal weight rows");
        return tensor_f64_zeros(0, 0);
    };

    let mv: TensorF64 = tensor_f64_matvec(x, &model.weights);
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(&mv) {
        data.push(mv.data[i] + model.bias);
        i = i + 1;
    };
    return tensor_f64_from_vec(mv.shape.rows, mv.shape.cols, data);
}

fn lasso_f64_predict(model: &LinearModelF64, x: &TensorF64) -> TensorF64 {
    return linear_model_f64_predict(model, x);
}

fn elastic_net_f64_predict(model: &LinearModelF64, x: &TensorF64) -> TensorF64 {
    return linear_model_f64_predict(model, x);
}

fn linear_multioutput_f64_predict(model: &LinearMultiOutputModelF64, x: &TensorF64) -> TensorF64 {
    if x.shape.cols != model.weights.shape.cols {
        print("learn error: multi-output linear input cols must equal weight cols");
        return tensor_f64_zeros(0, 0);
    };
    if tensor_f64_len(&model.bias) != model.weights.shape.rows {
        print("learn error: multi-output linear bias length must equal output count");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut out_col: i64 = 0;
        while out_col < model.weights.shape.rows {
            let mut value: f64 = model.bias.data[out_col];
            let mut c: i64 = 0;
            while c < x.shape.cols {
                value = value + tensor_f64_at(x, r, c) * tensor_f64_at(&model.weights, out_col, c);
                c = c + 1;
            };
            data.push(value);
            out_col = out_col + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, model.weights.shape.rows, data);
}

fn logistic_binary_f64_decision_function(model: &LogisticBinaryModelF64, x: &TensorF64) -> TensorF64 {
    if model.weights.shape.cols != 1 {
        print("learn error: logistic weights must be a single-column tensor");
        return tensor_f64_zeros(0, 0);
    };
    if x.shape.cols != model.weights.shape.rows {
        print("learn error: input cols must equal logistic weight rows");
        return tensor_f64_zeros(0, 0);
    };

    let mv: TensorF64 = tensor_f64_matvec(x, &model.weights);
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(&mv) {
        data.push(mv.data[i] + model.bias);
        i = i + 1;
    };
    return tensor_f64_from_vec(mv.shape.rows, mv.shape.cols, data);
}

fn logistic_binary_sigmoid_f64(x: f64) -> f64 {
    if x >= 0.0 {
        let z: f64 = learn_exp_f64(0.0 - x);
        return 1.0 / (1.0 + z);
    };
    let z: f64 = learn_exp_f64(x);
    return z / (1.0 + z);
}

fn logistic_binary_f64_predict_positive_proba(model: &LogisticBinaryModelF64, x: &TensorF64) -> TensorF64 {
    let score: TensorF64 = logistic_binary_f64_decision_function(model, x);
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(&score) {
        data.push(logistic_binary_sigmoid_f64(score.data[i]));
        i = i + 1;
    };
    return tensor_f64_from_vec(score.shape.rows, score.shape.cols, data);
}

fn logistic_binary_f64_predict_proba(model: &LogisticBinaryModelF64, x: &TensorF64) -> TensorF64 {
    let positive: TensorF64 = logistic_binary_f64_predict_positive_proba(model, x);
    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < positive.shape.rows {
        let p1: f64 = tensor_f64_at(&positive, r, 0);
        data.push(1.0 - p1);
        data.push(p1);
        r = r + 1;
    };
    return tensor_f64_from_vec(positive.shape.rows, 2, data);
}

fn logistic_binary_f64_predict(model: &LogisticBinaryModelF64, x: &TensorF64) -> TensorI64 {
    let score: TensorF64 = logistic_binary_f64_decision_function(model, x);
    if score.shape.rows == 0 {
        return tensor_i64_zeros(0, 0);
    };
    let mut data: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(&score) {
        if score.data[i] > 0.0 {
            data.push(model.positive_class);
        } else {
            data.push(model.negative_class);
        };
        i = i + 1;
    };
    return tensor_i64_from_vec(score.shape.rows, score.shape.cols, data);
}

fn logistic_multiclass_decision_function_f64(model: &LogisticMulticlassModelF64, x: &TensorF64) -> TensorF64 {
    if x.shape.cols != model.weights.shape.cols {
        print("learn error: multiclass logistic input cols must equal weight cols");
        return tensor_f64_zeros(0, 0);
    };
    if tensor_f64_len(&model.bias) != model.weights.shape.rows || tensor_i64_len(&model.classes) != model.weights.shape.rows {
        print("learn error: multiclass logistic class metadata length must equal class count");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut k: i64 = 0;
        while k < model.weights.shape.rows {
            let mut score: f64 = model.bias.data[k];
            let mut c: i64 = 0;
            while c < x.shape.cols {
                score = score + tensor_f64_at(x, r, c) * tensor_f64_at(&model.weights, k, c);
                c = c + 1;
            };
            data.push(score);
            k = k + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, model.weights.shape.rows, data);
}

fn logistic_multiclass_predict_proba_f64(model: &LogisticMulticlassModelF64, x: &TensorF64) -> TensorF64 {
    let score: TensorF64 = logistic_multiclass_decision_function_f64(model, x);
    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < score.shape.rows {
        let mut max_value: f64 = tensor_f64_at(&score, r, 0);
        let mut k: i64 = 1;
        while k < score.shape.cols {
            let value: f64 = tensor_f64_at(&score, r, k);
            if value > max_value {
                max_value = value;
            };
            k = k + 1;
        };
        let mut sum_exp: f64 = 0.0;
        k = 0;
        while k < score.shape.cols {
            sum_exp = sum_exp + learn_exp_f64(tensor_f64_at(&score, r, k) - max_value);
            k = k + 1;
        };
        k = 0;
        while k < score.shape.cols {
            data.push(learn_exp_f64(tensor_f64_at(&score, r, k) - max_value) / sum_exp);
            k = k + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(score.shape.rows, score.shape.cols, data);
}

fn logistic_multiclass_predict_i64(model: &LogisticMulticlassModelF64, x: &TensorF64) -> TensorI64 {
    let score: TensorF64 = logistic_multiclass_decision_function_f64(model, x);
    let mut labels: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < score.shape.rows {
        let mut best_index: i64 = 0;
        let mut best_value: f64 = tensor_f64_at(&score, r, 0);
        let mut k: i64 = 1;
        while k < score.shape.cols {
            let value: f64 = tensor_f64_at(&score, r, k);
            if value > best_value {
                best_value = value;
                best_index = k;
            };
            k = k + 1;
        };
        labels.push(model.classes.data[best_index]);
        r = r + 1;
    };
    return tensor_i64_from_vec(score.shape.rows, 1, labels);
}

fn linear_svc_decision_function_f64(model: &LinearSvcModelF64, x: &TensorF64) -> TensorF64 {
    if x.shape.cols != model.weights.shape.cols {
        print("learn error: LinearSVC input cols must equal weight cols");
        return tensor_f64_zeros(0, 0);
    };
    if tensor_f64_len(&model.bias) != model.weights.shape.rows || tensor_i64_len(&model.classes) != model.weights.shape.rows {
        print("learn error: LinearSVC class metadata length must equal class count");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut k: i64 = 0;
        while k < model.weights.shape.rows {
            let mut score: f64 = model.bias.data[k];
            let mut c: i64 = 0;
            while c < x.shape.cols {
                score = score + tensor_f64_at(x, r, c) * tensor_f64_at(&model.weights, k, c);
                c = c + 1;
            };
            data.push(score);
            k = k + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, model.weights.shape.rows, data);
}

fn linear_svc_predict_i64(model: &LinearSvcModelF64, x: &TensorF64) -> TensorI64 {
    let score: TensorF64 = linear_svc_decision_function_f64(model, x);
    let mut labels: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < score.shape.rows {
        let mut best_index: i64 = 0;
        let mut best_value: f64 = tensor_f64_at(&score, r, 0);
        let mut k: i64 = 1;
        while k < score.shape.cols {
            let value: f64 = tensor_f64_at(&score, r, k);
            if value > best_value {
                best_value = value;
                best_index = k;
            };
            k = k + 1;
        };
        labels.push(model.classes.data[best_index]);
        r = r + 1;
    };
    return tensor_i64_from_vec(score.shape.rows, 1, labels);
}

fn rbf_svc_binary_decision_function_f64(model: &RbfSvcBinaryModelF64, x: &TensorF64) -> TensorF64 {
    if x.shape.cols != model.support_vectors.shape.cols {
        print("learn error: RBF SVC input cols must equal support-vector cols");
        return tensor_f64_zeros(0, 0);
    };
    if tensor_f64_len(&model.dual_coef) != model.support_vectors.shape.rows {
        print("learn error: RBF SVC dual coef length must equal support-vector row count");
        return tensor_f64_zeros(0, 0);
    };
    if model.gamma <= 0.0 {
        print("learn error: RBF SVC gamma must be positive");
        return tensor_f64_zeros(0, 0);
    };

    let mut out: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut score: f64 = model.intercept;
        let mut sv: i64 = 0;
        while sv < model.support_vectors.shape.rows {
            let mut sq: f64 = 0.0;
            let mut c: i64 = 0;
            while c < x.shape.cols {
                let d: f64 = tensor_f64_at(x, r, c) - tensor_f64_at(&model.support_vectors, sv, c);
                sq = sq + d * d;
                c = c + 1;
            };
            score = score + model.dual_coef.data[sv] * learn_exp_f64((0.0 - model.gamma) * sq);
            sv = sv + 1;
        };
        out.push(score);
        r = r + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, 1, out);
}

fn rbf_svc_binary_predict_i64(model: &RbfSvcBinaryModelF64, x: &TensorF64) -> TensorI64 {
    let score: TensorF64 = rbf_svc_binary_decision_function_f64(model, x);
    if score.shape.rows <= 0 {
        return tensor_i64_zeros(0, 0);
    };

    let mut labels: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < score.shape.rows {
        if tensor_f64_at(&score, r, 0) >= 0.0 {
            labels.push(model.positive_class);
        } else {
            labels.push(model.negative_class);
        };
        r = r + 1;
    };
    return tensor_i64_from_vec(score.shape.rows, 1, labels);
}

fn decision_tree_classifier_node_count(model: &DecisionTreeClassifierF64) -> i64 {
    return vec_len(model.node_left_indices);
}

fn decision_tree_classifier_valid(model: &DecisionTreeClassifierF64) -> i64 {
    let node_count: i64 = decision_tree_classifier_node_count(model);
    let class_count: i64 = tensor_i64_len(&model.classes);
    if node_count <= 0 || class_count <= 0 {
        return 0;
    };
    if vec_len(model.node_right_indices) != node_count { return 0; };
    if vec_len(model.node_feature_indices) != node_count { return 0; };
    if vec_len(model.node_thresholds) != node_count { return 0; };
    if model.node_values.shape.rows != node_count { return 0; };
    if model.node_values.shape.cols != class_count { return 0; };
    return 1;
}

fn decision_tree_classifier_leaf_for_row(model: &DecisionTreeClassifierF64, x: &TensorF64, row: i64) -> i64 {
    let node_count: i64 = decision_tree_classifier_node_count(model);
    let mut node: i64 = 0;
    let mut guard: i64 = 0;
    while guard <= node_count {
        if node < 0 || node >= node_count {
            return -1;
        };
        let left: i64 = model.node_left_indices[node];
        let right: i64 = model.node_right_indices[node];
        if left < 0 && right < 0 {
            return node;
        };
        let feature: i64 = model.node_feature_indices[node];
        if feature < 0 || feature >= x.shape.cols {
            return -1;
        };
        if tensor_f64_at(x, row, feature) <= model.node_thresholds[node] {
            node = left;
        } else {
            node = right;
        };
        guard = guard + 1;
    };
    return -1;
}

fn decision_tree_classifier_apply_i64(model: &DecisionTreeClassifierF64, x: &TensorF64) -> TensorI64 {
    if decision_tree_classifier_valid(model) == 0 {
        print("learn error: DecisionTreeClassifier metadata is inconsistent");
        return tensor_i64_zeros(0, 0);
    };

    let mut leaves: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let leaf: i64 = decision_tree_classifier_leaf_for_row(model, x, r);
        if leaf < 0 {
            print("learn error: DecisionTreeClassifier traversal failed");
            return tensor_i64_zeros(0, 0);
        };
        leaves.push(leaf);
        r = r + 1;
    };
    return tensor_i64_from_vec(x.shape.rows, 1, leaves);
}

fn decision_tree_classifier_predict_proba_f64(model: &DecisionTreeClassifierF64, x: &TensorF64) -> TensorF64 {
    let leaves: TensorI64 = decision_tree_classifier_apply_i64(model, x);
    if leaves.shape.rows <= 0 {
        return tensor_f64_zeros(0, 0);
    };

    let class_count: i64 = tensor_i64_len(&model.classes);
    let mut out: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < leaves.shape.rows {
        let leaf: i64 = tensor_i64_at(&leaves, r, 0);
        let mut sum: f64 = 0.0;
        let mut c: i64 = 0;
        while c < class_count {
            sum = sum + tensor_f64_at(&model.node_values, leaf, c);
            c = c + 1;
        };
        if sum <= 0.0 {
            print("learn error: DecisionTreeClassifier leaf value sum must be positive");
            return tensor_f64_zeros(0, 0);
        };
        c = 0;
        while c < class_count {
            out.push(tensor_f64_at(&model.node_values, leaf, c) / sum);
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(leaves.shape.rows, class_count, out);
}

fn decision_tree_classifier_predict_i64(model: &DecisionTreeClassifierF64, x: &TensorF64) -> TensorI64 {
    let proba: TensorF64 = decision_tree_classifier_predict_proba_f64(model, x);
    if proba.shape.rows <= 0 {
        return tensor_i64_zeros(0, 0);
    };

    let mut labels: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < proba.shape.rows {
        let mut best_index: i64 = 0;
        let mut best_value: f64 = tensor_f64_at(&proba, r, 0);
        let mut c: i64 = 1;
        while c < proba.shape.cols {
            let value: f64 = tensor_f64_at(&proba, r, c);
            if value > best_value {
                best_value = value;
                best_index = c;
            };
            c = c + 1;
        };
        labels.push(model.classes.data[best_index]);
        r = r + 1;
    };
    return tensor_i64_from_vec(proba.shape.rows, 1, labels);
}

fn scaler_logistic_binary_pipeline_f64_decision_function(pipeline: &ScalerLogisticBinaryPipelineF64, x: &TensorF64) -> TensorF64 {
    let scaled: TensorF64 = standard_scaler_f64_transform(&pipeline.scaler, x);
    return logistic_binary_f64_decision_function(&pipeline.classifier, &scaled);
}

fn scaler_logistic_binary_pipeline_f64_predict(pipeline: &ScalerLogisticBinaryPipelineF64, x: &TensorF64) -> TensorI64 {
    let scaled: TensorF64 = standard_scaler_f64_transform(&pipeline.scaler, x);
    return logistic_binary_f64_predict(&pipeline.classifier, &scaled);
}

fn mse_f64(y_true: &TensorF64, y_pred: &TensorF64) -> f64 {
    if shape2_assert_same(&y_true.shape, &y_pred.shape) != 0 {
        return -1.0;
    };
    let mut acc: f64 = 0.0;
    let mut i: i64 = 0;
    while i < tensor_f64_len(y_true) {
        let d: f64 = y_true.data[i] - y_pred.data[i];
        acc = acc + d * d;
        i = i + 1;
    };
    return acc / (tensor_f64_len(y_true) as f64);
}

fn classification_accuracy_i64(y_true: &TensorI64, y_pred: &TensorI64) -> f64 {
    if shape2_assert_same(&y_true.shape, &y_pred.shape) != 0 {
        return -1.0;
    };
    let mut correct: i64 = 0;
    let mut i: i64 = 0;
    while i < tensor_i64_len(y_true) {
        if y_true.data[i] == y_pred.data[i] { correct = correct + 1; };
        i = i + 1;
    };
    return (correct as f64) / (tensor_i64_len(y_true) as f64);
}

fn kfold_accuracy_scores_i64(y_true: &TensorI64, y_pred: &TensorI64, test_indices: &TensorI64) -> TensorF64 {
    if shape2_assert_same(&y_true.shape, &y_pred.shape) != 0 {
        return tensor_f64_zeros(0, 0);
    };
    if test_indices.shape.rows <= 0 || test_indices.shape.cols <= 0 {
        print("learn error: kfold accuracy requires non-empty test-index matrix");
        return tensor_f64_zeros(0, 0);
    };

    let mut scores: Vec<f64> = Vec::new();
    let mut fold: i64 = 0;
    while fold < test_indices.shape.rows {
        let mut correct: i64 = 0;
        let mut c: i64 = 0;
        while c < test_indices.shape.cols {
            let idx: i64 = tensor_i64_at(test_indices, fold, c);
            if idx < 0 || idx >= tensor_i64_len(y_true) {
                print("learn error: kfold accuracy test index out of range");
                return tensor_f64_zeros(0, 0);
            };
            if y_true.data[idx] == y_pred.data[idx] {
                correct = correct + 1;
            };
            c = c + 1;
        };
        scores.push((correct as f64) / (test_indices.shape.cols as f64));
        fold = fold + 1;
    };
    return tensor_f64_from_vec(test_indices.shape.rows, 1, scores);
}

fn binary_confusion_counts_i64(y_true: &TensorI64, y_pred: &TensorI64, positive_class: i64) -> TensorI64 {
    if shape2_assert_same(&y_true.shape, &y_pred.shape) != 0 {
        return tensor_i64_zeros(0, 0);
    };

    let mut tn: i64 = 0;
    let mut fp: i64 = 0;
    let mut fn_count: i64 = 0;
    let mut tp: i64 = 0;
    let mut i: i64 = 0;
    while i < tensor_i64_len(y_true) {
        let truth_pos: bool = y_true.data[i] == positive_class;
        let pred_pos: bool = y_pred.data[i] == positive_class;
        if truth_pos && pred_pos {
            tp = tp + 1;
        };
        if truth_pos && !pred_pos {
            fn_count = fn_count + 1;
        };
        if !truth_pos && pred_pos {
            fp = fp + 1;
        };
        if !truth_pos && !pred_pos {
            tn = tn + 1;
        };
        i = i + 1;
    };

    let mut out: Vec<i64> = Vec::new();
    out.push(tn);
    out.push(fp);
    out.push(fn_count);
    out.push(tp);
    return tensor_i64_from_vec(4, 1, out);
}

fn binary_precision_i64(y_true: &TensorI64, y_pred: &TensorI64, positive_class: i64) -> f64 {
    let counts: TensorI64 = binary_confusion_counts_i64(y_true, y_pred, positive_class);
    if tensor_i64_len(&counts) != 4 {
        return 0.0;
    };
    let fp: i64 = counts.data[1];
    let tp: i64 = counts.data[3];
    let denom: i64 = tp + fp;
    if denom == 0 {
        return 0.0;
    };
    return (tp as f64) / (denom as f64);
}

fn binary_recall_i64(y_true: &TensorI64, y_pred: &TensorI64, positive_class: i64) -> f64 {
    let counts: TensorI64 = binary_confusion_counts_i64(y_true, y_pred, positive_class);
    if tensor_i64_len(&counts) != 4 {
        return 0.0;
    };
    let fn_count: i64 = counts.data[2];
    let tp: i64 = counts.data[3];
    let denom: i64 = tp + fn_count;
    if denom == 0 {
        return 0.0;
    };
    return (tp as f64) / (denom as f64);
}

fn binary_f1_i64(y_true: &TensorI64, y_pred: &TensorI64, positive_class: i64) -> f64 {
    let precision: f64 = binary_precision_i64(y_true, y_pred, positive_class);
    let recall: f64 = binary_recall_i64(y_true, y_pred, positive_class);
    if precision + recall == 0.0 {
        return 0.0;
    };
    return 2.0 * precision * recall / (precision + recall);
}

fn binary_log_loss_i64_f64(y_true: &TensorI64, positive_proba: &TensorF64, positive_class: i64) -> f64 {
    if shape2_assert_same(&y_true.shape, &positive_proba.shape) != 0 {
        return -1.0;
    };
    let eps: f64 = 0.000000000000001;
    let mut acc: f64 = 0.0;
    let mut i: i64 = 0;
    while i < tensor_i64_len(y_true) {
        let mut p: f64 = positive_proba.data[i];
        if p < eps {
            p = eps;
        };
        if p > 1.0 - eps {
            p = 1.0 - eps;
        };
        if y_true.data[i] == positive_class {
            acc = acc - learn_log_f64(p);
        } else {
            acc = acc - learn_log_f64(1.0 - p);
        };
        i = i + 1;
    };
    return acc / (tensor_i64_len(y_true) as f64);
}

fn binary_roc_auc_f64(y_true: &TensorI64, score: &TensorF64, positive_class: i64) -> f64 {
    if shape2_assert_same(&y_true.shape, &score.shape) != 0 {
        return 0.0;
    };

    let n: i64 = tensor_i64_len(y_true);
    let mut wins: f64 = 0.0;
    let mut pairs: f64 = 0.0;
    let mut i: i64 = 0;
    while i < n {
        if y_true.data[i] == positive_class {
            let mut j: i64 = 0;
            while j < n {
                if y_true.data[j] != positive_class {
                    pairs = pairs + 1.0;
                    if score.data[i] > score.data[j] {
                        wins = wins + 1.0;
                    };
                    if score.data[i] == score.data[j] {
                        wins = wins + 0.5;
                    };
                };
                j = j + 1;
            };
        };
        i = i + 1;
    };

    if pairs == 0.0 {
        return 0.0;
    };
    return wins / pairs;
}

fn kmeans_f64_squared_distance_row_center(x: &TensorF64, row: i64, centers: &TensorF64, center: i64) -> f64 {
    let mut acc: f64 = 0.0;
    let mut c: i64 = 0;
    while c < x.shape.cols {
        let diff: f64 = tensor_f64_at(x, row, c) - tensor_f64_at(centers, center, c);
        acc = acc + diff * diff;
        c = c + 1;
    };
    return acc;
}

fn kmeans_f64_transform(model: &KMeansF64, x: &TensorF64) -> TensorF64 {
    if x.shape.cols != model.centers.shape.cols {
        print("learn error: KMeans input cols must equal center cols");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut k: i64 = 0;
        while k < model.centers.shape.rows {
            let sq: f64 = kmeans_f64_squared_distance_row_center(x, r, &model.centers, k);
            data.push(learn_f64_sqrt_newton(sq));
            k = k + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, model.centers.shape.rows, data);
}

fn kmeans_f64_predict(model: &KMeansF64, x: &TensorF64) -> TensorI64 {
    if x.shape.cols != model.centers.shape.cols {
        print("learn error: KMeans input cols must equal center cols");
        return tensor_i64_zeros(0, 0);
    };

    let mut labels: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut best_label: i64 = 0;
        let mut best_sq: f64 = kmeans_f64_squared_distance_row_center(x, r, &model.centers, 0);
        let mut k: i64 = 1;
        while k < model.centers.shape.rows {
            let sq: f64 = kmeans_f64_squared_distance_row_center(x, r, &model.centers, k);
            if sq < best_sq {
                best_sq = sq;
                best_label = k;
            };
            k = k + 1;
        };
        labels.push(best_label);
        r = r + 1;
    };
    return tensor_i64_from_vec(x.shape.rows, 1, labels);
}

fn kmeans_f64_inertia(model: &KMeansF64, x: &TensorF64) -> f64 {
    if x.shape.cols != model.centers.shape.cols {
        print("learn error: KMeans input cols must equal center cols");
        return 0.0;
    };

    let mut acc: f64 = 0.0;
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut best_sq: f64 = kmeans_f64_squared_distance_row_center(x, r, &model.centers, 0);
        let mut k: i64 = 1;
        while k < model.centers.shape.rows {
            let sq: f64 = kmeans_f64_squared_distance_row_center(x, r, &model.centers, k);
            if sq < best_sq {
                best_sq = sq;
            };
            k = k + 1;
        };
        acc = acc + best_sq;
        r = r + 1;
    };
    return acc;
}

fn pca_f64_transform(model: &PcaF64, x: &TensorF64) -> TensorF64 {
    if model.mean.shape.rows != 1 {
        print("learn error: PCA mean must be a single row");
        return tensor_f64_zeros(0, 0);
    };
    if x.shape.cols != model.mean.shape.cols {
        print("learn error: PCA input cols must equal mean cols");
        return tensor_f64_zeros(0, 0);
    };
    if x.shape.cols != model.components.shape.cols {
        print("learn error: PCA input cols must equal component cols");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut k: i64 = 0;
        while k < model.components.shape.rows {
            let mut acc: f64 = 0.0;
            let mut c: i64 = 0;
            while c < x.shape.cols {
                acc = acc + (tensor_f64_at(x, r, c) - tensor_f64_at(&model.mean, 0, c)) * tensor_f64_at(&model.components, k, c);
                c = c + 1;
            };
            data.push(acc);
            k = k + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, model.components.shape.rows, data);
}

fn pca_f64_inverse_transform(model: &PcaF64, z: &TensorF64) -> TensorF64 {
    if model.mean.shape.rows != 1 {
        print("learn error: PCA mean must be a single row");
        return tensor_f64_zeros(0, 0);
    };
    if z.shape.cols != model.components.shape.rows {
        print("learn error: PCA latent cols must equal component count");
        return tensor_f64_zeros(0, 0);
    };
    if model.mean.shape.cols != model.components.shape.cols {
        print("learn error: PCA mean cols must equal component cols");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < z.shape.rows {
        let mut c: i64 = 0;
        while c < model.components.shape.cols {
            let mut value: f64 = tensor_f64_at(&model.mean, 0, c);
            let mut k: i64 = 0;
            while k < model.components.shape.rows {
                value = value + tensor_f64_at(z, r, k) * tensor_f64_at(&model.components, k, c);
                k = k + 1;
            };
            data.push(value);
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(z.shape.rows, model.components.shape.cols, data);
}

fn gaussian_nb_joint_log_likelihood_f64(model: &GaussianNBF64, x: &TensorF64) -> TensorF64 {
    if model.theta.shape.rows != model.var.shape.rows || model.theta.shape.cols != model.var.shape.cols {
        print("learn error: GaussianNB theta and var shapes must match");
        return tensor_f64_zeros(0, 0);
    };
    if x.shape.cols != model.theta.shape.cols {
        print("learn error: GaussianNB input cols must equal feature count");
        return tensor_f64_zeros(0, 0);
    };
    if tensor_f64_len(&model.class_prior) != model.theta.shape.rows || tensor_i64_len(&model.classes) != model.theta.shape.rows {
        print("learn error: GaussianNB class metadata length must equal class count");
        return tensor_f64_zeros(0, 0);
    };

    let log_two_pi: f64 = learn_log_f64(6.283185307179586);
    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut k: i64 = 0;
        while k < model.theta.shape.rows {
            let mut value: f64 = learn_log_f64(model.class_prior.data[k]);
            let mut c: i64 = 0;
            while c < x.shape.cols {
                let variance: f64 = tensor_f64_at(&model.var, k, c);
                let diff: f64 = tensor_f64_at(x, r, c) - tensor_f64_at(&model.theta, k, c);
                value = value - 0.5 * (log_two_pi + learn_log_f64(variance)) - 0.5 * diff * diff / variance;
                c = c + 1;
            };
            data.push(value);
            k = k + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, model.theta.shape.rows, data);
}

fn gaussian_nb_predict_log_proba_f64(model: &GaussianNBF64, x: &TensorF64) -> TensorF64 {
    let joint: TensorF64 = gaussian_nb_joint_log_likelihood_f64(model, x);
    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < joint.shape.rows {
        let mut max_value: f64 = tensor_f64_at(&joint, r, 0);
        let mut k: i64 = 1;
        while k < joint.shape.cols {
            let value: f64 = tensor_f64_at(&joint, r, k);
            if value > max_value {
                max_value = value;
            };
            k = k + 1;
        };

        let mut sum_exp: f64 = 0.0;
        k = 0;
        while k < joint.shape.cols {
            sum_exp = sum_exp + learn_exp_f64(tensor_f64_at(&joint, r, k) - max_value);
            k = k + 1;
        };
        let normalizer: f64 = max_value + learn_log_f64(sum_exp);
        k = 0;
        while k < joint.shape.cols {
            data.push(tensor_f64_at(&joint, r, k) - normalizer);
            k = k + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(joint.shape.rows, joint.shape.cols, data);
}

fn gaussian_nb_predict_proba_f64(model: &GaussianNBF64, x: &TensorF64) -> TensorF64 {
    let log_proba: TensorF64 = gaussian_nb_predict_log_proba_f64(model, x);
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(&log_proba) {
        data.push(learn_exp_f64(log_proba.data[i]));
        i = i + 1;
    };
    return tensor_f64_from_vec(log_proba.shape.rows, log_proba.shape.cols, data);
}

fn gaussian_nb_predict_i64(model: &GaussianNBF64, x: &TensorF64) -> TensorI64 {
    let joint: TensorF64 = gaussian_nb_joint_log_likelihood_f64(model, x);
    let mut labels: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < joint.shape.rows {
        let mut best_index: i64 = 0;
        let mut best_value: f64 = tensor_f64_at(&joint, r, 0);
        let mut k: i64 = 1;
        while k < joint.shape.cols {
            let value: f64 = tensor_f64_at(&joint, r, k);
            if value > best_value {
                best_value = value;
                best_index = k;
            };
            k = k + 1;
        };
        labels.push(model.classes.data[best_index]);
        r = r + 1;
    };
    return tensor_i64_from_vec(joint.shape.rows, 1, labels);
}

fn multinomial_nb_joint_log_likelihood_f64(model: &MultinomialNBF64, x: &TensorF64) -> TensorF64 {
    if x.shape.cols != model.feature_log_prob.shape.cols {
        print("learn error: MultinomialNB input cols must equal feature count");
        return tensor_f64_zeros(0, 0);
    };
    if tensor_f64_len(&model.class_log_prior) != model.feature_log_prob.shape.rows || tensor_i64_len(&model.classes) != model.feature_log_prob.shape.rows {
        print("learn error: MultinomialNB class metadata length must equal class count");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut k: i64 = 0;
        while k < model.feature_log_prob.shape.rows {
            let mut value: f64 = model.class_log_prior.data[k];
            let mut c: i64 = 0;
            while c < x.shape.cols {
                value = value + tensor_f64_at(x, r, c) * tensor_f64_at(&model.feature_log_prob, k, c);
                c = c + 1;
            };
            data.push(value);
            k = k + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, model.feature_log_prob.shape.rows, data);
}

fn multinomial_nb_predict_log_proba_f64(model: &MultinomialNBF64, x: &TensorF64) -> TensorF64 {
    let joint: TensorF64 = multinomial_nb_joint_log_likelihood_f64(model, x);
    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < joint.shape.rows {
        let mut max_value: f64 = tensor_f64_at(&joint, r, 0);
        let mut k: i64 = 1;
        while k < joint.shape.cols {
            let value: f64 = tensor_f64_at(&joint, r, k);
            if value > max_value { max_value = value; };
            k = k + 1;
        };

        let mut sum_exp: f64 = 0.0;
        k = 0;
        while k < joint.shape.cols {
            sum_exp = sum_exp + learn_exp_f64(tensor_f64_at(&joint, r, k) - max_value);
            k = k + 1;
        };
        let normalizer: f64 = max_value + learn_log_f64(sum_exp);
        k = 0;
        while k < joint.shape.cols {
            data.push(tensor_f64_at(&joint, r, k) - normalizer);
            k = k + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(joint.shape.rows, joint.shape.cols, data);
}

fn multinomial_nb_predict_proba_f64(model: &MultinomialNBF64, x: &TensorF64) -> TensorF64 {
    let log_proba: TensorF64 = multinomial_nb_predict_log_proba_f64(model, x);
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(&log_proba) {
        data.push(learn_exp_f64(log_proba.data[i]));
        i = i + 1;
    };
    return tensor_f64_from_vec(log_proba.shape.rows, log_proba.shape.cols, data);
}

fn multinomial_nb_predict_i64(model: &MultinomialNBF64, x: &TensorF64) -> TensorI64 {
    let joint: TensorF64 = multinomial_nb_joint_log_likelihood_f64(model, x);
    let mut labels: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < joint.shape.rows {
        let mut best_index: i64 = 0;
        let mut best_value: f64 = tensor_f64_at(&joint, r, 0);
        let mut k: i64 = 1;
        while k < joint.shape.cols {
            let value: f64 = tensor_f64_at(&joint, r, k);
            if value > best_value {
                best_value = value;
                best_index = k;
            };
            k = k + 1;
        };
        labels.push(model.classes.data[best_index]);
        r = r + 1;
    };
    return tensor_i64_from_vec(joint.shape.rows, 1, labels);
}

fn bernoulli_nb_joint_log_likelihood_f64(model: &BernoulliNBF64, x: &TensorF64) -> TensorF64 {
    if x.shape.cols != model.feature_log_prob.shape.cols {
        print("learn error: BernoulliNB input cols must equal feature count");
        return tensor_f64_zeros(0, 0);
    };
    if tensor_f64_len(&model.class_log_prior) != model.feature_log_prob.shape.rows || tensor_i64_len(&model.classes) != model.feature_log_prob.shape.rows {
        print("learn error: BernoulliNB class metadata length must equal class count");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut k: i64 = 0;
        while k < model.feature_log_prob.shape.rows {
            let mut value: f64 = model.class_log_prior.data[k];
            let mut c: i64 = 0;
            while c < x.shape.cols {
                let pos_log_prob: f64 = tensor_f64_at(&model.feature_log_prob, k, c);
                let neg_log_prob: f64 = learn_log_f64(1.0 - learn_exp_f64(pos_log_prob));
                if tensor_f64_at(x, r, c) > 0.0 {
                    value = value + pos_log_prob;
                } else {
                    value = value + neg_log_prob;
                };
                c = c + 1;
            };
            data.push(value);
            k = k + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, model.feature_log_prob.shape.rows, data);
}

fn bernoulli_nb_predict_log_proba_f64(model: &BernoulliNBF64, x: &TensorF64) -> TensorF64 {
    let joint: TensorF64 = bernoulli_nb_joint_log_likelihood_f64(model, x);
    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < joint.shape.rows {
        let mut max_value: f64 = tensor_f64_at(&joint, r, 0);
        let mut k: i64 = 1;
        while k < joint.shape.cols {
            let value: f64 = tensor_f64_at(&joint, r, k);
            if value > max_value { max_value = value; };
            k = k + 1;
        };

        let mut sum_exp: f64 = 0.0;
        k = 0;
        while k < joint.shape.cols {
            sum_exp = sum_exp + learn_exp_f64(tensor_f64_at(&joint, r, k) - max_value);
            k = k + 1;
        };
        let normalizer: f64 = max_value + learn_log_f64(sum_exp);
        k = 0;
        while k < joint.shape.cols {
            data.push(tensor_f64_at(&joint, r, k) - normalizer);
            k = k + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(joint.shape.rows, joint.shape.cols, data);
}

fn bernoulli_nb_predict_proba_f64(model: &BernoulliNBF64, x: &TensorF64) -> TensorF64 {
    let log_proba: TensorF64 = bernoulli_nb_predict_log_proba_f64(model, x);
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(&log_proba) {
        data.push(learn_exp_f64(log_proba.data[i]));
        i = i + 1;
    };
    return tensor_f64_from_vec(log_proba.shape.rows, log_proba.shape.cols, data);
}

fn bernoulli_nb_predict_i64(model: &BernoulliNBF64, x: &TensorF64) -> TensorI64 {
    let joint: TensorF64 = bernoulli_nb_joint_log_likelihood_f64(model, x);
    let mut labels: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < joint.shape.rows {
        let mut best_index: i64 = 0;
        let mut best_value: f64 = tensor_f64_at(&joint, r, 0);
        let mut k: i64 = 1;
        while k < joint.shape.cols {
            let value: f64 = tensor_f64_at(&joint, r, k);
            if value > best_value {
                best_value = value;
                best_index = k;
            };
            k = k + 1;
        };
        labels.push(model.classes.data[best_index]);
        r = r + 1;
    };
    return tensor_i64_from_vec(joint.shape.rows, 1, labels);
}

fn knn_f64_squared_distance_row_row(x: &TensorF64, row: i64, train: &TensorF64, train_row: i64) -> f64 {
    let mut acc: f64 = 0.0;
    let mut c: i64 = 0;
    while c < x.shape.cols {
        let diff: f64 = tensor_f64_at(x, row, c) - tensor_f64_at(train, train_row, c);
        acc = acc + diff * diff;
        c = c + 1;
    };
    return acc;
}

fn knn_1nn_distances_f64(model: &KnnClassifierF64, x: &TensorF64) -> TensorF64 {
    if x.shape.cols != model.x_train.shape.cols {
        print("learn error: KNN input cols must equal train cols");
        return tensor_f64_zeros(0, 0);
    };

    let mut out: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut best_sq: f64 = knn_f64_squared_distance_row_row(x, r, &model.x_train, 0);
        let mut tr: i64 = 1;
        while tr < model.x_train.shape.rows {
            let sq: f64 = knn_f64_squared_distance_row_row(x, r, &model.x_train, tr);
            if sq < best_sq {
                best_sq = sq;
            };
            tr = tr + 1;
        };
        out.push(learn_f64_sqrt_newton(best_sq));
        r = r + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, 1, out);
}

fn knn_1nn_indices_i64(model: &KnnClassifierF64, x: &TensorF64) -> TensorI64 {
    if x.shape.cols != model.x_train.shape.cols {
        print("learn error: KNN input cols must equal train cols");
        return tensor_i64_zeros(0, 0);
    };

    let mut out: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut best_index: i64 = 0;
        let mut best_sq: f64 = knn_f64_squared_distance_row_row(x, r, &model.x_train, 0);
        let mut tr: i64 = 1;
        while tr < model.x_train.shape.rows {
            let sq: f64 = knn_f64_squared_distance_row_row(x, r, &model.x_train, tr);
            if sq < best_sq {
                best_sq = sq;
                best_index = tr;
            };
            tr = tr + 1;
        };
        out.push(best_index);
        r = r + 1;
    };
    return tensor_i64_from_vec(x.shape.rows, 1, out);
}

fn knn_1nn_predict_i64(model: &KnnClassifierF64, x: &TensorF64) -> TensorI64 {
    let indices: TensorI64 = knn_1nn_indices_i64(model, x);
    let mut out: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_i64_len(&indices) {
        out.push(model.y_train.data[indices.data[i]]);
        i = i + 1;
    };
    return tensor_i64_from_vec(indices.shape.rows, 1, out);
}

fn knn_train_k_indices_i64(train: &TensorF64, x: &TensorF64, k_count: i64) -> TensorI64 {
    if x.shape.cols != train.shape.cols {
        print("learn error: nearest-neighbor input cols must equal train cols");
        return tensor_i64_zeros(0, 0);
    };
    if k_count <= 0 || k_count > train.shape.rows {
        print("learn error: nearest-neighbor k must be between one and train row count");
        return tensor_i64_zeros(0, 0);
    };

    let mut out: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < x.shape.rows {
        let mut selected: Vec<i64> = Vec::new();
        let mut rank: i64 = 0;
        while rank < k_count {
            let mut best_index: i64 = -1;
            let mut best_sq: f64 = 0.0;
            let mut tr: i64 = 0;
            while tr < train.shape.rows {
                let mut already_selected: i64 = 0;
                let mut seen: i64 = 0;
                while seen < rank {
                    if selected[seen] == tr {
                        already_selected = 1;
                    };
                    seen = seen + 1;
                };
                if already_selected == 0 {
                    let sq: f64 = knn_f64_squared_distance_row_row(x, r, train, tr);
                    if best_index < 0 || sq < best_sq {
                        best_sq = sq;
                        best_index = tr;
                    };
                };
                tr = tr + 1;
            };
            selected.push(best_index);
            out.push(best_index);
            rank = rank + 1;
        };
        r = r + 1;
    };
    return tensor_i64_from_vec(x.shape.rows, k_count, out);
}

fn knn_train_k_distances_f64(train: &TensorF64, x: &TensorF64, k_count: i64) -> TensorF64 {
    let indices: TensorI64 = knn_train_k_indices_i64(train, x, k_count);
    if indices.shape.rows <= 0 {
        return tensor_f64_zeros(0, 0);
    };

    let mut out: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < indices.shape.rows {
        let mut c: i64 = 0;
        while c < indices.shape.cols {
            let train_row: i64 = tensor_i64_at(&indices, r, c);
            let sq: f64 = knn_f64_squared_distance_row_row(x, r, train, train_row);
            out.push(learn_f64_sqrt_newton(sq));
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(indices.shape.rows, indices.shape.cols, out);
}

fn knn_k_indices_i64(model: &KnnClassifierF64, x: &TensorF64, k_count: i64) -> TensorI64 {
    return knn_train_k_indices_i64(&model.x_train, x, k_count);
}

fn knn_k_distances_f64(model: &KnnClassifierF64, x: &TensorF64, k_count: i64) -> TensorF64 {
    return knn_train_k_distances_f64(&model.x_train, x, k_count);
}

fn nearest_neighbors_kneighbors_indices_i64(model: &NearestNeighborsF64, x: &TensorF64, k_count: i64) -> TensorI64 {
    return knn_train_k_indices_i64(&model.x_train, x, k_count);
}

fn nearest_neighbors_kneighbors_distances_f64(model: &NearestNeighborsF64, x: &TensorF64, k_count: i64) -> TensorF64 {
    return knn_train_k_distances_f64(&model.x_train, x, k_count);
}

fn knn_k_predict_i64(model: &KnnClassifierF64, x: &TensorF64, k_count: i64, classes: &TensorI64) -> TensorI64 {
    if model.y_train.shape.rows != model.x_train.shape.rows || model.y_train.shape.cols != 1 {
        print("learn error: KNN labels must be a single column matching train rows");
        return tensor_i64_zeros(0, 0);
    };
    if tensor_i64_len(classes) <= 0 {
        print("learn error: KNN classes must be non-empty");
        return tensor_i64_zeros(0, 0);
    };

    let indices: TensorI64 = knn_k_indices_i64(model, x, k_count);
    if indices.shape.rows <= 0 {
        return tensor_i64_zeros(0, 0);
    };

    let mut out: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < indices.shape.rows {
        let mut counts: Vec<i64> = Vec::new();
        let mut ci: i64 = 0;
        while ci < tensor_i64_len(classes) {
            counts.push(0);
            ci = ci + 1;
        };

        let mut c: i64 = 0;
        while c < indices.shape.cols {
            let train_row: i64 = tensor_i64_at(&indices, r, c);
            let label: i64 = model.y_train.data[train_row];
            let class_index: i64 = learn_class_index_i64(classes, label);
            if class_index < 0 {
                print("learn error: KNN label outside classes");
                return tensor_i64_zeros(0, 0);
            };
            vec_set(counts, class_index, counts[class_index] + 1);
            c = c + 1;
        };

        let mut best_class_index: i64 = 0;
        let mut best_count: i64 = counts[0];
        ci = 1;
        while ci < tensor_i64_len(classes) {
            if counts[ci] > best_count {
                best_count = counts[ci];
                best_class_index = ci;
            };
            ci = ci + 1;
        };
        out.push(classes.data[best_class_index]);
        r = r + 1;
    };
    return tensor_i64_from_vec(indices.shape.rows, 1, out);
}

fn knn_k_predict_proba_i64(model: &KnnClassifierF64, x: &TensorF64, k_count: i64, classes: &TensorI64) -> TensorF64 {
    if model.y_train.shape.rows != model.x_train.shape.rows || model.y_train.shape.cols != 1 {
        print("learn error: KNN labels must be a single column matching train rows");
        return tensor_f64_zeros(0, 0);
    };
    let class_count: i64 = tensor_i64_len(classes);
    if class_count <= 0 {
        print("learn error: KNN classes must be non-empty");
        return tensor_f64_zeros(0, 0);
    };

    let indices: TensorI64 = knn_k_indices_i64(model, x, k_count);
    if indices.shape.rows <= 0 {
        return tensor_f64_zeros(0, 0);
    };

    let mut out: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < indices.shape.rows {
        let mut counts: Vec<i64> = Vec::new();
        let mut ci: i64 = 0;
        while ci < class_count {
            counts.push(0);
            ci = ci + 1;
        };

        let mut c: i64 = 0;
        while c < indices.shape.cols {
            let train_row: i64 = tensor_i64_at(&indices, r, c);
            let class_index: i64 = learn_class_index_i64(classes, model.y_train.data[train_row]);
            if class_index < 0 {
                print("learn error: KNN label outside classes");
                return tensor_f64_zeros(0, 0);
            };
            vec_set(counts, class_index, counts[class_index] + 1);
            c = c + 1;
        };

        ci = 0;
        while ci < class_count {
            out.push((counts[ci] as f64) / (indices.shape.cols as f64));
            ci = ci + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(indices.shape.rows, class_count, out);
}

fn knn_k_predict_distance_weighted_i64(model: &KnnClassifierF64, x: &TensorF64, k_count: i64, classes: &TensorI64) -> TensorI64 {
    if model.y_train.shape.rows != model.x_train.shape.rows || model.y_train.shape.cols != 1 {
        print("learn error: KNN labels must be a single column matching train rows");
        return tensor_i64_zeros(0, 0);
    };
    if tensor_i64_len(classes) <= 0 {
        print("learn error: KNN classes must be non-empty");
        return tensor_i64_zeros(0, 0);
    };

    let indices: TensorI64 = knn_k_indices_i64(model, x, k_count);
    if indices.shape.rows <= 0 {
        return tensor_i64_zeros(0, 0);
    };

    let mut out: Vec<i64> = Vec::new();
    let mut r: i64 = 0;
    while r < indices.shape.rows {
        let mut weights: Vec<f64> = Vec::new();
        let mut ci: i64 = 0;
        while ci < tensor_i64_len(classes) {
            weights.push(0.0);
            ci = ci + 1;
        };

        let mut c: i64 = 0;
        while c < indices.shape.cols {
            let train_row: i64 = tensor_i64_at(&indices, r, c);
            let label: i64 = model.y_train.data[train_row];
            let class_index: i64 = learn_class_index_i64(classes, label);
            if class_index < 0 {
                print("learn error: KNN label outside classes");
                return tensor_i64_zeros(0, 0);
            };
            let sq: f64 = knn_f64_squared_distance_row_row(x, r, &model.x_train, train_row);
            let mut weight: f64 = 1000000000000.0;
            if sq > 0.0 {
                weight = 1.0 / learn_f64_sqrt_newton(sq);
            };
            vec_set(weights, class_index, weights[class_index] + weight);
            c = c + 1;
        };

        let mut best_class_index: i64 = 0;
        let mut best_weight: f64 = weights[0];
        ci = 1;
        while ci < tensor_i64_len(classes) {
            if weights[ci] > best_weight {
                best_weight = weights[ci];
                best_class_index = ci;
            };
            ci = ci + 1;
        };
        out.push(classes.data[best_class_index]);
        r = r + 1;
    };
    return tensor_i64_from_vec(indices.shape.rows, 1, out);
}

fn knn_k_predict_proba_distance_weighted_i64(model: &KnnClassifierF64, x: &TensorF64, k_count: i64, classes: &TensorI64) -> TensorF64 {
    if model.y_train.shape.rows != model.x_train.shape.rows || model.y_train.shape.cols != 1 {
        print("learn error: KNN labels must be a single column matching train rows");
        return tensor_f64_zeros(0, 0);
    };
    let class_count: i64 = tensor_i64_len(classes);
    if class_count <= 0 {
        print("learn error: KNN classes must be non-empty");
        return tensor_f64_zeros(0, 0);
    };

    let indices: TensorI64 = knn_k_indices_i64(model, x, k_count);
    if indices.shape.rows <= 0 {
        return tensor_f64_zeros(0, 0);
    };

    let mut out: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < indices.shape.rows {
        let mut weights: Vec<f64> = Vec::new();
        let mut ci: i64 = 0;
        while ci < class_count {
            weights.push(0.0);
            ci = ci + 1;
        };

        let mut total_weight: f64 = 0.0;
        let mut c: i64 = 0;
        while c < indices.shape.cols {
            let train_row: i64 = tensor_i64_at(&indices, r, c);
            let class_index: i64 = learn_class_index_i64(classes, model.y_train.data[train_row]);
            if class_index < 0 {
                print("learn error: KNN label outside classes");
                return tensor_f64_zeros(0, 0);
            };
            let sq: f64 = knn_f64_squared_distance_row_row(x, r, &model.x_train, train_row);
            let mut weight: f64 = 1000000000000.0;
            if sq > 0.0 {
                weight = 1.0 / learn_f64_sqrt_newton(sq);
            };
            vec_set(weights, class_index, weights[class_index] + weight);
            total_weight = total_weight + weight;
            c = c + 1;
        };
        if total_weight <= 0.0 {
            print("learn error: KNN total distance weight must be positive");
            return tensor_f64_zeros(0, 0);
        };

        ci = 0;
        while ci < class_count {
            out.push(weights[ci] / total_weight);
            ci = ci + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(indices.shape.rows, class_count, out);
}

fn confusion_matrix_i64(y_true: &TensorI64, y_pred: &TensorI64, class_count: i64) -> TensorI64 {
    if shape2_assert_same(&y_true.shape, &y_pred.shape) != 0 {
        return tensor_i64_zeros(0, 0);
    };
    let mut data: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < class_count * class_count {
        data.push(0);
        i = i + 1;
    };

    i = 0;
    while i < tensor_i64_len(y_true) {
        let truth: i64 = y_true.data[i];
        let pred: i64 = y_pred.data[i];
        if truth >= 0 && truth < class_count && pred >= 0 && pred < class_count {
            let idx: i64 = truth * class_count + pred;
            vec_set(data, idx, data[idx] + 1);
        };
        i = i + 1;
    };
    return tensor_i64_from_vec(class_count, class_count, data);
}

fn multiclass_precision_recall_f1_support_i64(y_true: &TensorI64, y_pred: &TensorI64, classes: &TensorI64) -> TensorF64 {
    if shape2_assert_same(&y_true.shape, &y_pred.shape) != 0 {
        return tensor_f64_zeros(0, 0);
    };
    let class_count: i64 = tensor_i64_len(classes);
    if class_count <= 0 {
        print("learn error: multiclass metrics classes must be non-empty");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut ci: i64 = 0;
    while ci < class_count {
        let label: i64 = classes.data[ci];
        let mut tp: i64 = 0;
        let mut fp: i64 = 0;
        let mut fn_count: i64 = 0;
        let mut support: i64 = 0;
        let mut i: i64 = 0;
        while i < tensor_i64_len(y_true) {
            let truth_pos: bool = y_true.data[i] == label;
            let pred_pos: bool = y_pred.data[i] == label;
            if truth_pos {
                support = support + 1;
            };
            if truth_pos && pred_pos {
                tp = tp + 1;
            };
            if !truth_pos && pred_pos {
                fp = fp + 1;
            };
            if truth_pos && !pred_pos {
                fn_count = fn_count + 1;
            };
            i = i + 1;
        };

        let mut precision: f64 = 0.0;
        let precision_denom: i64 = tp + fp;
        if precision_denom > 0 {
            precision = (tp as f64) / (precision_denom as f64);
        };
        let mut recall: f64 = 0.0;
        let recall_denom: i64 = tp + fn_count;
        if recall_denom > 0 {
            recall = (tp as f64) / (recall_denom as f64);
        };
        let mut f1: f64 = 0.0;
        if precision + recall > 0.0 {
            f1 = 2.0 * precision * recall / (precision + recall);
        };
        data.push(precision);
        data.push(recall);
        data.push(f1);
        data.push(support as f64);
        ci = ci + 1;
    };
    return tensor_f64_from_vec(class_count, 4, data);
}

fn multiclass_macro_precision_recall_f1_i64(y_true: &TensorI64, y_pred: &TensorI64, classes: &TensorI64) -> TensorF64 {
    let metrics: TensorF64 = multiclass_precision_recall_f1_support_i64(y_true, y_pred, classes);
    if metrics.shape.rows <= 0 {
        return tensor_f64_zeros(0, 0);
    };

    let mut precision_sum: f64 = 0.0;
    let mut recall_sum: f64 = 0.0;
    let mut f1_sum: f64 = 0.0;
    let mut r: i64 = 0;
    while r < metrics.shape.rows {
        precision_sum = precision_sum + tensor_f64_at(&metrics, r, 0);
        recall_sum = recall_sum + tensor_f64_at(&metrics, r, 1);
        f1_sum = f1_sum + tensor_f64_at(&metrics, r, 2);
        r = r + 1;
    };

    let denom: f64 = metrics.shape.rows as f64;
    let mut out: Vec<f64> = Vec::new();
    out.push(precision_sum / denom);
    out.push(recall_sum / denom);
    out.push(f1_sum / denom);
    return tensor_f64_from_vec(1, 3, out);
}

fn multiclass_weighted_precision_recall_f1_i64(y_true: &TensorI64, y_pred: &TensorI64, classes: &TensorI64) -> TensorF64 {
    let metrics: TensorF64 = multiclass_precision_recall_f1_support_i64(y_true, y_pred, classes);
    if metrics.shape.rows <= 0 {
        return tensor_f64_zeros(0, 0);
    };

    let mut support_sum: f64 = 0.0;
    let mut r: i64 = 0;
    while r < metrics.shape.rows {
        support_sum = support_sum + tensor_f64_at(&metrics, r, 3);
        r = r + 1;
    };
    if support_sum <= 0.0 {
        let mut zeros: Vec<f64> = Vec::new();
        zeros.push(0.0);
        zeros.push(0.0);
        zeros.push(0.0);
        return tensor_f64_from_vec(1, 3, zeros);
    };

    let mut precision_sum: f64 = 0.0;
    let mut recall_sum: f64 = 0.0;
    let mut f1_sum: f64 = 0.0;
    r = 0;
    while r < metrics.shape.rows {
        let support: f64 = tensor_f64_at(&metrics, r, 3);
        precision_sum = precision_sum + tensor_f64_at(&metrics, r, 0) * support;
        recall_sum = recall_sum + tensor_f64_at(&metrics, r, 1) * support;
        f1_sum = f1_sum + tensor_f64_at(&metrics, r, 2) * support;
        r = r + 1;
    };

    let mut out: Vec<f64> = Vec::new();
    out.push(precision_sum / support_sum);
    out.push(recall_sum / support_sum);
    out.push(f1_sum / support_sum);
    return tensor_f64_from_vec(1, 3, out);
}
