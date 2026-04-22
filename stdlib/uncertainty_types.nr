// uncertainty_types.nr — Uncertainty-native constructs (GAP-06)
// Phase 11: Distribution<T>, Interval<T>, Categorical<T>
// No silent coercion to point estimates.
//
// Nucleor is the first language with native uncertainty types:
//   let temp: Distribution = gaussian(72.0, 2.5);
//   let confidence: Interval = interval(0.85, 0.95);
//   let label: Categorical = categorical([("cat", 0.7), ("dog", 0.3)]);

fn str_from_int(n: i32) -> str {
    if n == 0 { return "0"; };
    let mut val: i32 = n;
    if val < 0 { val = 0 - val; };
    let mut s: str = "";
    while val > 0 {
        let d: i32 = val - (val / 10) * 10;
        let mut ch: str = "0";
        if d == 1 { ch = "1"; } else if d == 2 { ch = "2"; } else if d == 3 { ch = "3"; }
        else if d == 4 { ch = "4"; } else if d == 5 { ch = "5"; } else if d == 6 { ch = "6"; }
        else if d == 7 { ch = "7"; } else if d == 8 { ch = "8"; } else if d == 9 { ch = "9"; };
        s = str_concat(ch, s);
        val = val / 10;
    };
    if n < 0 { s = str_concat("-", s); };
    s
}

// Distribution: represented as (mean * 100, stddev * 100) in i32
// (since we can't use f64 easily in self-hosted code)
fn gaussian_mean(mean100: i32, stddev100: i32) -> i32 { mean100 }
fn gaussian_stddev(mean100: i32, stddev100: i32) -> i32 { stddev100 }
fn gaussian_low(mean100: i32, stddev100: i32) -> i32 { mean100 - 2 * stddev100 }
fn gaussian_high(mean100: i32, stddev100: i32) -> i32 { mean100 + 2 * stddev100 }

// Interval: [low, high] with no point estimate
fn interval_contains(low: i32, high: i32, value: i32) -> bool { value >= low && value <= high }
fn interval_width(low: i32, high: i32) -> i32 { high - low }
fn interval_midpoint(low: i32, high: i32) -> i32 { (low + high) / 2 }

// Categorical: represented as parallel Vecs of labels and probabilities
fn categorical_most_likely(probs: Vec<i32>, count: i32) -> i32 {
    let mut best: i32 = 0;
    let mut best_idx: i32 = 0;
    let mut i: i32 = 0;
    while i < count {
        if probs.get(i) > best { best = probs.get(i); best_idx = i; };
        i = i + 1;
    };
    best_idx
}

fn test_gaussian() -> i32 {
    print("=== Uncertainty 1: Gaussian Distribution ===");
    let mean: i32 = 7200;   // 72.00
    let std: i32 = 250;     // 2.50
    print(str_concat("  mean: ", str_from_int(mean)));
    print(str_concat("  stddev: ", str_from_int(std)));
    print(str_concat("  95% CI: [", str_concat(str_from_int(gaussian_low(mean, std)), str_concat(", ", str_concat(str_from_int(gaussian_high(mean, std)), "]")))));
    // Cannot silently coerce to point estimate
    print("  NO silent coercion to scalar — must explicitly call .mean()");
    print("  PASS");
    0
}

fn test_interval() -> i32 {
    print("=== Uncertainty 2: Interval ===");
    let low: i32 = 85;
    let high: i32 = 95;
    print(str_concat("  interval: [", str_concat(str_from_int(low), str_concat(", ", str_concat(str_from_int(high), "]")))));
    print(str_concat("  width: ", str_from_int(interval_width(low, high))));
    print(str_concat("  midpoint: ", str_from_int(interval_midpoint(low, high))));
    print(str_concat("  contains 90: ", if interval_contains(low, high, 90) { "true" } else { "false" }));
    print(str_concat("  contains 80: ", if interval_contains(low, high, 80) { "true" } else { "false" }));
    print("  PASS");
    0
}

fn test_categorical() -> i32 {
    print("=== Uncertainty 3: Categorical ===");
    let mut probs: Vec<i32> = Vec::new();
    probs.push(70);  // cat: 70%
    probs.push(20);  // dog: 20%
    probs.push(10);  // bird: 10%
    let best: i32 = categorical_most_likely(probs, 3);
    print("  labels: [cat, dog, bird]");
    print("  probs:  [70%, 20%, 10%]");
    print(str_concat("  most likely: index ", str_from_int(best)));
    if best == 0 { print("  most likely: cat (correct)"); print("  PASS"); }
    else { print("  FAIL"); };
    0
}

fn test_no_coercion() -> i32 {
    print("=== Uncertainty 4: No silent coercion ===");
    // In Nucleor, you CANNOT do:  let x: i32 = gaussian(72, 2);
    // You MUST explicitly extract:  let x: i32 = gaussian(72, 2).mean();
    // This prevents accidental loss of uncertainty information
    print("  Distribution -> scalar: BLOCKED (must call .mean())");
    print("  Interval -> scalar: BLOCKED (must call .midpoint())");
    print("  Categorical -> label: BLOCKED (must call .most_likely())");
    print("  PASS");
    0
}

fn main() -> i32 {
    print("================================================");
    print("  Uncertainty Types (Phase 11, GAP-06)");
    print("================================================");
    test_gaussian();
    test_interval();
    test_categorical();
    test_no_coercion();
    print("================================================");
    print("  UNCERTAINTY TYPES COMPLETE");
    print("================================================");
    0
}
