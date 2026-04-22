// rods/mps — Matrix Product States (efficient quantum simulation)
#cfile "../runtime/mps_rt.c"

extern fn nuc_mps_init(nq: i64, max_bond: i64) -> i64;
extern fn nuc_mps_gate(h: i64, gate_type: i64, q0: i64, q1: i64, angle: i64);
extern fn nuc_mps_extract(h: i64) -> i64;
extern fn nuc_mps_free(h: i64);
extern fn nuc_mps_max_bond(h: i64) -> i64;
extern fn nuc_mps_expect_z(h: i64, q: i64) -> i64;

fn mps_init(nq: i64, max_bond: i64) -> i64 { return nuc_mps_init(nq, max_bond); }
fn mps_gate(h: i64, gate_type: i64, q0: i64, q1: i64, angle: i64) { nuc_mps_gate(h, gate_type, q0, q1, angle); }
fn mps_extract(h: i64) -> i64 { return nuc_mps_extract(h); }
fn mps_free(h: i64) { nuc_mps_free(h); }
fn mps_max_bond(h: i64) -> i64 { return nuc_mps_max_bond(h); }
fn mps_expect_z(h: i64, q: i64) -> i64 { return nuc_mps_expect_z(h, q); }
