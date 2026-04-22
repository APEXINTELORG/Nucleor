// rods/comm — Distributed-training collective communication primitives
// (allreduce, broadcast, reduce-scatter, all-gather) plus gradient
// accumulation buffers. Pure single-process simulation; doesn't require
// MPI or NCCL.
#cfile "../runtime/comm_rt.c"

extern fn nuc_comm_init(world_size: i64, buffer_size: i64) -> i64;
extern fn nuc_comm_set_data(wh: i64, rank: i64, data: i64, n: i64);
extern fn nuc_comm_get_data(wh: i64, rank: i64, n: i64) -> i64;
extern fn nuc_comm_allreduce_ring(wh: i64, n: i64);
extern fn nuc_comm_broadcast(wh: i64, src_rank: i64, n: i64);
extern fn nuc_comm_reduce_scatter(wh: i64, n: i64);
extern fn nuc_comm_all_gather(wh: i64, chunk_size: i64);
extern fn nuc_comm_grad_accum_new(size: i64, accum_steps: i64) -> i64;
extern fn nuc_comm_grad_accum_add(ga: i64, grad: i64) -> i64;
extern fn nuc_comm_grad_accum_get(ga: i64) -> i64;
extern fn nuc_comm_grad_accum_reset(ga: i64);
extern fn nuc_comm_free(wh: i64);

fn comm_init(world: i64, bufsize: i64) -> i64 { return nuc_comm_init(world, bufsize); }
fn comm_set(wh: i64, rank: i64, data: i64, n: i64) { nuc_comm_set_data(wh, rank, data, n); }
fn comm_get(wh: i64, rank: i64, n: i64) -> i64 { return nuc_comm_get_data(wh, rank, n); }
fn comm_allreduce(wh: i64, n: i64) { nuc_comm_allreduce_ring(wh, n); }
fn comm_broadcast(wh: i64, src: i64, n: i64) { nuc_comm_broadcast(wh, src, n); }
fn comm_reduce_scatter(wh: i64, n: i64) { nuc_comm_reduce_scatter(wh, n); }
fn comm_all_gather(wh: i64, chunk: i64) { nuc_comm_all_gather(wh, chunk); }
fn grad_accum_new(size: i64, steps: i64) -> i64 { return nuc_comm_grad_accum_new(size, steps); }
fn grad_accum_add(ga: i64, grad: i64) -> i64 { return nuc_comm_grad_accum_add(ga, grad); }
fn grad_accum_get(ga: i64) -> i64 { return nuc_comm_grad_accum_get(ga); }
fn grad_accum_reset(ga: i64) { nuc_comm_grad_accum_reset(ga); }
fn comm_free(wh: i64) { nuc_comm_free(wh); }
