// =====================================================
// rods/ssm — State Space Models (modern ML)
// =====================================================
// Import: import "stdlib/rods/ssm.nr"
// Provides: Mamba-style selective scan, SSD chunked algorithm,
//   RWKV WKV (linear-attention), xLSTM cell, ZOH discretization.
// =====================================================

#cfile "../runtime/ssm_rt.c"

extern fn nuc_ssm_selective_scan(x: i64, delta: i64, A: i64, B: i64, C: i64, L: i64, D: i64, N: i64) -> i64;
extern fn nuc_ssm_ssd_chunked(x: i64, A: i64, B: i64, C: i64, L: i64, D: i64, N: i64, chunk_size: i64) -> i64;
extern fn nuc_ssm_rwkv_wkv(w: i64, k: i64, v: i64, r: i64, L: i64, D_head: i64) -> i64;
extern fn nuc_ssm_xlstm_cell(x: i64, Wf: i64, Wi: i64, Wz: i64, Wo: i64, L: i64, D: i64) -> i64;
extern fn nuc_ssm_discretize_zoh(A: i64, B: i64, delta: i64, N: i64) -> i64;

fn ssm_selective_scan(x: i64, delta: i64, A: i64, B: i64, C: i64, L: i64, D: i64, N: i64) -> i64 {
    return nuc_ssm_selective_scan(x, delta, A, B, C, L, D, N);
}
fn ssm_ssd_chunked(x: i64, A: i64, B: i64, C: i64, L: i64, D: i64, N: i64, chunk_size: i64) -> i64 {
    return nuc_ssm_ssd_chunked(x, A, B, C, L, D, N, chunk_size);
}
fn ssm_rwkv_wkv(w: i64, k: i64, v: i64, r: i64, L: i64, D_head: i64) -> i64 {
    return nuc_ssm_rwkv_wkv(w, k, v, r, L, D_head);
}
fn ssm_xlstm_cell(x: i64, Wf: i64, Wi: i64, Wz: i64, Wo: i64, L: i64, D: i64) -> i64 {
    return nuc_ssm_xlstm_cell(x, Wf, Wi, Wz, Wo, L, D);
}
fn ssm_discretize_zoh(A: i64, B: i64, delta: i64, N: i64) -> i64 {
    return nuc_ssm_discretize_zoh(A, B, delta, N);
}
