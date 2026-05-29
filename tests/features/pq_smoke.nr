// v0.8.237 stdlib/rods/pq.nr first test coverage.
//
// Product Quantization for vector search (codebook training,
// encoding, asymmetric distance computation). Pre-v0.8.237:
// zero coverage on the standalone rod.
//
// Setup: 4 vectors of dim 4, split into M=2 subspaces of sd=2,
// K=2 centroids per subspace. Vectors 0/1 are identical at
// (1, 1, 5, 5); vectors 2/3 are at (-1, -1, -5, -5). K-means
// on each subspace separates the two clusters cleanly.
//
// Locks four invariants:
//
//   1. pq_train returns valid handle — non-zero.
//   2. Encoded code Vec has length M — one cluster index
//      per subspace.
//   3. Same-cluster vectors get same codes — vectors 0 and
//      1 are identical; their PQ codes match.
//   4. Different-cluster vectors get different codes — at
//      least one of the M subspaces splits cluster A vs B.
//
// Distance table / ADC / search use raw arrays in the codebook
// space; deferred.
//
// Expected: rc=0.

import "stdlib/rods/pq.nr"

fn build_vec4(a: f64, b: f64, c: f64, d: f64) -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(a));
    v.push(f64_to_bits(b));
    v.push(f64_to_bits(c));
    v.push(f64_to_bits(d));
    return v;
}

fn build_data() -> i64 {
    let mut data: Vec<i64> = Vec::new();
    // Vec 0: (1, 1, 5, 5)
    data.push(f64_to_bits(1.0)); data.push(f64_to_bits(1.0));
    data.push(f64_to_bits(5.0)); data.push(f64_to_bits(5.0));
    // Vec 1: (1, 1, 5, 5) — identical to 0
    data.push(f64_to_bits(1.0)); data.push(f64_to_bits(1.0));
    data.push(f64_to_bits(5.0)); data.push(f64_to_bits(5.0));
    // Vec 2: (-1, -1, -5, -5)
    data.push(f64_to_bits(0.0 - 1.0)); data.push(f64_to_bits(0.0 - 1.0));
    data.push(f64_to_bits(0.0 - 5.0)); data.push(f64_to_bits(0.0 - 5.0));
    // Vec 3: (-1, -1, -5, -5) — identical to 2
    data.push(f64_to_bits(0.0 - 1.0)); data.push(f64_to_bits(0.0 - 1.0));
    data.push(f64_to_bits(0.0 - 5.0)); data.push(f64_to_bits(0.0 - 5.0));
    return data;
}

fn check_train_valid() -> i64 {
    let data: i64 = build_data();
    let pq: i64 = pq_train(data, 4, 4, 2, 2);
    if pq == 0 { return 1; };
    pq_free(pq);
    return 0;
}

fn check_encoded_length() -> i64 {
    let data: i64 = build_data();
    let pq: i64 = pq_train(data, 4, 4, 2, 2);
    let vec0: i64 = build_vec4(1.0, 1.0, 5.0, 5.0);
    let codes: i64 = pq_encode(pq, vec0);
    let n: i64 = vec_len(codes);
    pq_free(pq);
    if n != 2 { return 2; };
    return 0;
}

fn codes_eq(a: i64, b: i64) -> i64 {
    if vec_len(a) != vec_len(b) { return 0; };
    let n: i64 = vec_len(a);
    let mut i: i64 = 0;
    while i < n {
        if vec_get(a, i) != vec_get(b, i) { return 0; };
        i = i + 1;
    };
    return 1;
}

fn check_same_cluster_same_codes() -> i64 {
    let data: i64 = build_data();
    let pq: i64 = pq_train(data, 4, 4, 2, 2);
    let v0: i64 = build_vec4(1.0, 1.0, 5.0, 5.0);
    let v1: i64 = build_vec4(1.0, 1.0, 5.0, 5.0);
    let c0: i64 = pq_encode(pq, v0);
    let c1: i64 = pq_encode(pq, v1);
    pq_free(pq);
    if codes_eq(c0, c1) != 1 { return 4; };
    return 0;
}

fn check_diff_cluster_diff_codes() -> i64 {
    let data: i64 = build_data();
    let pq: i64 = pq_train(data, 4, 4, 2, 2);
    let v_pos: i64 = build_vec4(1.0, 1.0, 5.0, 5.0);
    let v_neg: i64 = build_vec4(0.0 - 1.0, 0.0 - 1.0, 0.0 - 5.0, 0.0 - 5.0);
    let c_pos: i64 = pq_encode(pq, v_pos);
    let c_neg: i64 = pq_encode(pq, v_neg);
    pq_free(pq);
    if codes_eq(c_pos, c_neg) == 1 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_train_valid();
    fails = fails + check_encoded_length();
    fails = fails + check_same_cluster_same_codes();
    fails = fails + check_diff_cluster_diff_codes();
    return fails;
}
