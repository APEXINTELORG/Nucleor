// random_extras — RFC-0017 stdlib enrichment.
//
//   random_int(lo, hi)        -> i64   inclusive range
//   random_bool()             -> i64   0 or 1
//   random_choice(vec)        -> i64   pick a random element
//   vec_shuffle(v)                     in-place Fisher-Yates
//   vec_sample(v, k)          -> Vec   k random elements (no replacement)
//   random_fill(v, lo, hi)             overwrite each cell with rng_int(lo, hi)

fn main() -> i64 {
    let mut fail: i64 = 0;
    rng_seed(42, 1337);

    // random_int: in range [3, 7]
    let mut i: i64 = 0;
    while i < 50 {
        let v: i64 = random_int(3, 7);
        if v < 3 || v > 7 {
            fail = fail + 1; print("FAIL random_int range");
            i = 50;
        };
        i = i + 1;
    };

    // random_bool: only 0 or 1
    i = 0;
    while i < 50 {
        let b: i64 = random_bool();
        if b < 0 || b > 1 {
            fail = fail + 1; print("FAIL random_bool range");
            i = 50;
        };
        i = i + 1;
    };

    // random_choice
    let pool: Vec<i64> = vec_new();
    vec_push(pool, 100); vec_push(pool, 200); vec_push(pool, 300);
    let pick: i64 = random_choice(pool);
    if pick != 100 && pick != 200 && pick != 300 {
        fail = fail + 1; print("FAIL random_choice");
    };

    // vec_shuffle: preserves multiset (sum invariant)
    let arr: Vec<i64> = vec_new();
    let mut k: i64 = 0;
    while k < 10 { vec_push(arr, k); k = k + 1; };
    let sum_before: i64 = vec_sum_i64(arr);
    vec_shuffle(arr);
    if vec_sum_i64(arr) != sum_before {
        fail = fail + 1; print("FAIL shuffle sum");
    };
    if vec_len(arr) != 10 {
        fail = fail + 1; print("FAIL shuffle len");
    };

    // vec_sample: k <= len returns exactly k elements; all from source
    let samp: Vec<i64> = vec_sample(arr, 3);
    if vec_len(samp) != 3 {
        fail = fail + 1; print("FAIL sample count");
    };
    let mut j: i64 = 0;
    while j < vec_len(samp) {
        if vec_contains_i64(arr, vec_get(samp, j)) != 1 {
            fail = fail + 1; print("FAIL sample membership");
            j = vec_len(samp);
        };
        j = j + 1;
    };

    // vec_sample: k > len returns at most len
    let big: Vec<i64> = vec_sample(arr, 1000);
    if vec_len(big) != 10 {
        fail = fail + 1; print("FAIL sample over");
    };

    // random_fill: every element in range
    let buf: Vec<i64> = vec_new();
    let mut m: i64 = 0;
    while m < 20 { vec_push(buf, 0); m = m + 1; };
    random_fill(buf, 1, 6);
    let mut t: i64 = 0;
    while t < vec_len(buf) {
        let val: i64 = vec_get(buf, t);
        if val < 1 || val > 6 {
            fail = fail + 1; print("FAIL fill range");
            t = vec_len(buf);
        };
        t = t + 1;
    };

    if fail == 0 { print("OK random_extras"); return 0; };
    return 1;
}
