// rods/ml/stats_facade — SciPy / statsmodels parity rods (mean, var, std, covariance, Pearson, quantile, histogram, normal, t-tests)
//
import "stdlib/rods/ml/tensor_facade.nr"
import "stdlib/rods/ml/math_facade.nr"
import "stdlib/rods/math_typed_special.nr"

// stats_facade.nr - SciPy/statsmodels-style descriptive statistics.

#[repr(C)]
struct StatsHistogramF64 {
    counts: TensorI64,
    bin_edges: TensorF64
}

#[repr(C)]
struct StatsTestResultF64 {
    statistic: f64,
    pvalue_two_sided: f64,
    df: f64
}

fn stats_sqrt_two_pi_f64() -> f64 {
    return 2.5066282746310002;
}

fn stats_abs_f64(x: f64) -> f64 {
    if x < 0.0 {
        return 0.0 - x;
    };
    return x;
}

fn stats_mean_f64(x: &TensorF64) -> f64 {
    if tensor_f64_len(x) == 0 {
        print("stats error: mean requires at least one value");
        return 0.0;
    };
    return tensor_f64_sum(x) / (tensor_f64_len(x) as f64);
}

fn stats_variance_f64(x: &TensorF64, ddof: i64) -> f64 {
    let n: i64 = tensor_f64_len(x);
    if n <= ddof {
        print("stats error: variance requires n > ddof");
        return 0.0;
    };

    let mean: f64 = stats_mean_f64(x);
    let mut acc: f64 = 0.0;
    let mut i: i64 = 0;
    while i < n {
        let delta: f64 = x.data[i] - mean;
        acc = acc + delta * delta;
        i = i + 1;
    };
    return acc / ((n - ddof) as f64);
}

fn stats_std_f64(x: &TensorF64, ddof: i64) -> f64 {
    return math_sqrt_f64(stats_variance_f64(x, ddof));
}

fn stats_covariance_f64(x: &TensorF64, y: &TensorF64, ddof: i64) -> f64 {
    let n: i64 = tensor_f64_len(x);
    if n != tensor_f64_len(y) {
        print("stats error: covariance inputs must have the same length");
        return 0.0;
    };
    if n <= ddof {
        print("stats error: covariance requires n > ddof");
        return 0.0;
    };

    let mean_x: f64 = stats_mean_f64(x);
    let mean_y: f64 = stats_mean_f64(y);
    let mut acc: f64 = 0.0;
    let mut i: i64 = 0;
    while i < n {
        acc = acc + (x.data[i] - mean_x) * (y.data[i] - mean_y);
        i = i + 1;
    };
    return acc / ((n - ddof) as f64);
}

fn stats_pearsonr_f64(x: &TensorF64, y: &TensorF64) -> f64 {
    let cov: f64 = stats_covariance_f64(x, y, 0);
    let sx: f64 = stats_std_f64(x, 0);
    let sy: f64 = stats_std_f64(y, 0);
    if sx == 0.0 || sy == 0.0 {
        print("stats error: pearsonr requires nonzero variance");
        return 0.0;
    };
    return cov / (sx * sy);
}

fn stats_zscore_f64(x: &TensorF64, ddof: i64) -> TensorF64 {
    let n: i64 = tensor_f64_len(x);
    if n == 0 {
        print("stats error: zscore requires at least one value");
        return tensor_f64_zeros(0, 0);
    };

    let mean: f64 = stats_mean_f64(x);
    let std: f64 = stats_std_f64(x, ddof);
    if std == 0.0 {
        print("stats error: zscore requires nonzero standard deviation");
        return tensor_f64_zeros(x.shape.rows, x.shape.cols);
    };

    let mut out: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < n {
        out.push((x.data[i] - mean) / std);
        i = i + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, x.shape.cols, out);
}

fn stats_sorted_values_f64(x: &TensorF64) -> TensorF64 {
    let n: i64 = tensor_f64_len(x);
    let mut out: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < n {
        out.push(x.data[i]);
        i = i + 1;
    };

    let mut a: i64 = 0;
    while a < n {
        let mut b: i64 = 0;
        while b + 1 < n - a {
            if out[b] > out[b + 1] {
                let tmp: f64 = out[b];
                vec_set(out, b, out[b + 1]);
                vec_set(out, b + 1, tmp);
            };
            b = b + 1;
        };
        a = a + 1;
    };

    return tensor_f64_from_vec(n, 1, out);
}

fn stats_quantile_f64(x: &TensorF64, q: f64) -> f64 {
    let n: i64 = tensor_f64_len(x);
    if n == 0 {
        print("stats error: quantile requires at least one value");
        return 0.0;
    };
    if q < 0.0 || q > 1.0 {
        print("stats error: quantile q must be in [0, 1]");
        return 0.0;
    };

    let sorted: TensorF64 = stats_sorted_values_f64(x);
    if n == 1 {
        return sorted.data[0];
    };

    let pos: f64 = ((n - 1) as f64) * q;
    let lo: i64 = pos as i64;
    let mut hi: i64 = lo + 1;
    if hi >= n {
        hi = n - 1;
    };
    let weight: f64 = pos - (lo as f64);
    return sorted.data[lo] * (1.0 - weight) + sorted.data[hi] * weight;
}

fn stats_median_f64(x: &TensorF64) -> f64 {
    return stats_quantile_f64(x, 0.5);
}

fn stats_iqr_f64(x: &TensorF64) -> f64 {
    return stats_quantile_f64(x, 0.75) - stats_quantile_f64(x, 0.25);
}

fn stats_min_f64(x: &TensorF64) -> f64 {
    let n: i64 = tensor_f64_len(x);
    if n == 0 {
        print("stats error: min requires at least one value");
        return 0.0;
    };

    let mut best: f64 = x.data[0];
    let mut i: i64 = 1;
    while i < n {
        if x.data[i] < best {
            best = x.data[i];
        };
        i = i + 1;
    };
    return best;
}

fn stats_max_f64(x: &TensorF64) -> f64 {
    let n: i64 = tensor_f64_len(x);
    if n == 0 {
        print("stats error: max requires at least one value");
        return 0.0;
    };

    let mut best: f64 = x.data[0];
    let mut i: i64 = 1;
    while i < n {
        if x.data[i] > best {
            best = x.data[i];
        };
        i = i + 1;
    };
    return best;
}

fn stats_argmin_i64(x: &TensorF64) -> i64 {
    let n: i64 = tensor_f64_len(x);
    if n == 0 {
        print("stats error: argmin requires at least one value");
        return -1;
    };

    let mut best_index: i64 = 0;
    let mut best_value: f64 = x.data[0];
    let mut i: i64 = 1;
    while i < n {
        if x.data[i] < best_value {
            best_index = i;
            best_value = x.data[i];
        };
        i = i + 1;
    };
    return best_index;
}

fn stats_argmax_i64(x: &TensorF64) -> i64 {
    let n: i64 = tensor_f64_len(x);
    if n == 0 {
        print("stats error: argmax requires at least one value");
        return -1;
    };

    let mut best_index: i64 = 0;
    let mut best_value: f64 = x.data[0];
    let mut i: i64 = 1;
    while i < n {
        if x.data[i] > best_value {
            best_index = i;
            best_value = x.data[i];
        };
        i = i + 1;
    };
    return best_index;
}

fn stats_range_f64(x: &TensorF64) -> f64 {
    return stats_max_f64(x) - stats_min_f64(x);
}

fn stats_rankdata_average_f64(x: &TensorF64) -> TensorF64 {
    let n: i64 = tensor_f64_len(x);
    if n == 0 {
        print("stats error: rankdata requires at least one value");
        return tensor_f64_zeros(0, 0);
    };

    let mut ranks: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < n {
        let mut less_count: i64 = 0;
        let mut equal_count: i64 = 0;
        let mut j: i64 = 0;
        while j < n {
            if x.data[j] < x.data[i] {
                less_count = less_count + 1;
            };
            if x.data[j] == x.data[i] {
                equal_count = equal_count + 1;
            };
            j = j + 1;
        };

        let start_rank: i64 = less_count + 1;
        let end_rank: i64 = less_count + equal_count;
        ranks.push(((start_rank + end_rank) as f64) / 2.0);
        i = i + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, x.shape.cols, ranks);
}

fn stats_histogram_fixed_width_f64(x: &TensorF64, start: f64, end: f64, bin_count: i64) -> StatsHistogramF64 {
    if bin_count <= 0 {
        print("stats error: histogram requires positive bin count");
        return StatsHistogramF64 {
            counts: tensor_i64_zeros(0, 0),
            bin_edges: tensor_f64_zeros(0, 0)
        };
    };
    if end <= start {
        print("stats error: histogram end must be greater than start");
        return StatsHistogramF64 {
            counts: tensor_i64_zeros(0, 0),
            bin_edges: tensor_f64_zeros(0, 0)
        };
    };

    let width: f64 = (end - start) / (bin_count as f64);
    let mut counts: Vec<i64> = Vec::new();
    let mut c: i64 = 0;
    while c < bin_count {
        counts.push(0);
        c = c + 1;
    };

    let n: i64 = tensor_f64_len(x);
    let mut i: i64 = 0;
    while i < n {
        let value: f64 = x.data[i];
        if value >= start && value <= end {
            let mut bin_index: i64 = ((value - start) / width) as i64;
            if bin_index >= bin_count {
                bin_index = bin_count - 1;
            };
            if bin_index >= 0 {
                vec_set(counts, bin_index, counts[bin_index] + 1);
            };
        };
        i = i + 1;
    };

    let mut edges: Vec<f64> = Vec::new();
    let mut e: i64 = 0;
    while e <= bin_count {
        edges.push(start + width * (e as f64));
        e = e + 1;
    };

    return StatsHistogramF64 {
        counts: tensor_i64_from_vec(bin_count, 1, counts),
        bin_edges: tensor_f64_from_vec(bin_count + 1, 1, edges)
    };
}

fn stats_normal_pdf_f64(x: f64, mean: f64, std: f64) -> f64 {
    if std <= 0.0 {
        print("stats error: normal pdf requires positive standard deviation");
        return 0.0;
    };

    let z: f64 = (x - mean) / std;
    return math_exp_f64(-0.5 * z * z) / (std * stats_sqrt_two_pi_f64());
}

fn stats_standard_normal_cdf_approx_f64(z: f64) -> f64 {
    let mut x: f64 = z;
    let mut sign: f64 = 1.0;
    if x < 0.0 {
        x = 0.0 - x;
        sign = -1.0;
    };

    let t: f64 = 1.0 / (1.0 + 0.2316419 * x);
    let poly: f64 = (((((1.330274429 * t) - 1.821255978) * t + 1.781477937) * t - 0.356563782) * t + 0.319381530) * t;
    let approx_positive: f64 = 1.0 - stats_normal_pdf_f64(x, 0.0, 1.0) * poly;
    if sign < 0.0 {
        return 1.0 - approx_positive;
    };
    return approx_positive;
}

fn stats_normal_cdf_approx_f64(x: f64, mean: f64, std: f64) -> f64 {
    if std <= 0.0 {
        print("stats error: normal cdf requires positive standard deviation");
        return 0.0;
    };

    return stats_standard_normal_cdf_approx_f64((x - mean) / std);
}

fn stats_normal_pdf_tensor_f64(x: &TensorF64, mean: f64, std: f64) -> TensorF64 {
    let n: i64 = tensor_f64_len(x);
    let mut out: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < n {
        out.push(stats_normal_pdf_f64(x.data[i], mean, std));
        i = i + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, x.shape.cols, out);
}

fn stats_normal_cdf_approx_tensor_f64(x: &TensorF64, mean: f64, std: f64) -> TensorF64 {
    let n: i64 = tensor_f64_len(x);
    let mut out: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < n {
        out.push(stats_normal_cdf_approx_f64(x.data[i], mean, std));
        i = i + 1;
    };
    return tensor_f64_from_vec(x.shape.rows, x.shape.cols, out);
}

fn stats_two_sided_normal_pvalue_approx_f64(statistic: f64) -> f64 {
    let tail: f64 = 1.0 - stats_standard_normal_cdf_approx_f64(stats_abs_f64(statistic));
    let mut p: f64 = 2.0 * tail;
    if p < 0.0 {
        p = 0.0;
    };
    if p > 1.0 {
        p = 1.0;
    };
    return p;
}

fn stats_ttest_1samp_normal_approx_f64(x: &TensorF64, popmean: f64) -> StatsTestResultF64 {
    let n: i64 = tensor_f64_len(x);
    if n < 2 {
        print("stats error: one-sample t-test requires at least two values");
        return StatsTestResultF64 { statistic: 0.0, pvalue_two_sided: 1.0, df: 0.0 };
    };

    let sample_std: f64 = stats_std_f64(x, 1);
    if sample_std == 0.0 {
        print("stats error: one-sample t-test requires nonzero sample standard deviation");
        return StatsTestResultF64 { statistic: 0.0, pvalue_two_sided: 1.0, df: (n - 1) as f64 };
    };

    let stderr: f64 = sample_std / math_sqrt_f64(n as f64);
    let statistic: f64 = (stats_mean_f64(x) - popmean) / stderr;
    return StatsTestResultF64 {
        statistic: statistic,
        pvalue_two_sided: stats_two_sided_normal_pvalue_approx_f64(statistic),
        df: (n - 1) as f64
    };
}

fn stats_ttest_1samp_f64(x: &TensorF64, popmean: f64) -> StatsTestResultF64 {
    let n: i64 = tensor_f64_len(x);
    if n < 2 {
        print("stats error: one-sample t-test requires at least two values");
        return StatsTestResultF64 { statistic: 0.0, pvalue_two_sided: 1.0, df: 0.0 };
    };

    let sample_std: f64 = stats_std_f64(x, 1);
    if sample_std == 0.0 {
        print("stats error: one-sample t-test requires nonzero sample standard deviation");
        return StatsTestResultF64 { statistic: 0.0, pvalue_two_sided: 1.0, df: (n - 1) as f64 };
    };

    let df: f64 = (n - 1) as f64;
    let stderr: f64 = sample_std / math_sqrt_f64(n as f64);
    let statistic: f64 = (stats_mean_f64(x) - popmean) / stderr;
    return StatsTestResultF64 {
        statistic: statistic,
        pvalue_two_sided: student_t_sf2_f64(statistic, df),
        df: df
    };
}

fn stats_welch_ttest_normal_approx_f64(x: &TensorF64, y: &TensorF64) -> StatsTestResultF64 {
    let nx: i64 = tensor_f64_len(x);
    let ny: i64 = tensor_f64_len(y);
    if nx < 2 || ny < 2 {
        print("stats error: Welch t-test requires at least two values in each input");
        return StatsTestResultF64 { statistic: 0.0, pvalue_two_sided: 1.0, df: 0.0 };
    };

    let vx: f64 = stats_variance_f64(x, 1);
    let vy: f64 = stats_variance_f64(y, 1);
    let ax: f64 = vx / (nx as f64);
    let ay: f64 = vy / (ny as f64);
    let denom: f64 = math_sqrt_f64(ax + ay);
    if denom == 0.0 {
        print("stats error: Welch t-test requires nonzero pooled standard error");
        return StatsTestResultF64 { statistic: 0.0, pvalue_two_sided: 1.0, df: 0.0 };
    };

    let statistic: f64 = (stats_mean_f64(x) - stats_mean_f64(y)) / denom;
    let df_num: f64 = (ax + ay) * (ax + ay);
    let df_den: f64 = (ax * ax) / ((nx - 1) as f64) + (ay * ay) / ((ny - 1) as f64);
    let mut df: f64 = 0.0;
    if df_den > 0.0 {
        df = df_num / df_den;
    };

    return StatsTestResultF64 {
        statistic: statistic,
        pvalue_two_sided: stats_two_sided_normal_pvalue_approx_f64(statistic),
        df: df
    };
}

fn stats_welch_ttest_f64(x: &TensorF64, y: &TensorF64) -> StatsTestResultF64 {
    let nx: i64 = tensor_f64_len(x);
    let ny: i64 = tensor_f64_len(y);
    if nx < 2 || ny < 2 {
        print("stats error: Welch t-test requires at least two values in each input");
        return StatsTestResultF64 { statistic: 0.0, pvalue_two_sided: 1.0, df: 0.0 };
    };

    let vx: f64 = stats_variance_f64(x, 1);
    let vy: f64 = stats_variance_f64(y, 1);
    let ax: f64 = vx / (nx as f64);
    let ay: f64 = vy / (ny as f64);
    let denom: f64 = math_sqrt_f64(ax + ay);
    if denom == 0.0 {
        print("stats error: Welch t-test requires nonzero pooled standard error");
        return StatsTestResultF64 { statistic: 0.0, pvalue_two_sided: 1.0, df: 0.0 };
    };

    let statistic: f64 = (stats_mean_f64(x) - stats_mean_f64(y)) / denom;
    let df_num: f64 = (ax + ay) * (ax + ay);
    let df_den: f64 = (ax * ax) / ((nx - 1) as f64) + (ay * ay) / ((ny - 1) as f64);
    let mut df: f64 = 0.0;
    if df_den > 0.0 {
        df = df_num / df_den;
    };

    return StatsTestResultF64 {
        statistic: statistic,
        pvalue_two_sided: student_t_sf2_f64(statistic, df),
        df: df
    };
}
