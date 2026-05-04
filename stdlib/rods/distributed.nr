// rods/distributed — RFC-0055 Phase A: distributed collectives
// + sharding-spec surface (rod-only).
//
// The full RFC-0055 ship adds language-level
// `ShardedTensor<T, Shape, ShardSpec>` + topology-aware
// dispatch (NCCL / RCCL / MPI / RDMA) + fault-domain replication.
// Phase A (this rod) lands the canonical collectives surface +
// ShardSpec tags + rank/world_size scaffolding. On a single
// rank (the only Phase A configuration) collectives are
// pass-through identity ops. Phase B promotes to per-backend
// dispatch.
//
// Sister to RFC-0052 / 53 / 54 Phase A landings — V2 frontier
// Tier-B follow-on after the Tier-A close-out at v0.7.90.
//
// Workflow today:
//
//   import "stdlib/rods/distributed.nr"
//
//   distributed_init(0, 1);                    // rank=0, world=1
//   let r: i64 = distributed_rank();
//   let w: i64 = distributed_world_size();
//
//   // Collectives (single-rank pass-through):
//   let summed: i64 = all_reduce(handle, reduce_op_sum());
//   let bcast: i64 = broadcast(handle, 0);
//
//   // Sharding tags:
//   let s: i64 = shard_spec_tensor_parallel(0);
//   if shard_spec_kind(s) == shard_spec_kind_shard() { ... };

#cfile "../runtime/distributed_rt.c"

extern fn nuc_dist_init(rank: i64, world_size: i64) -> i64;
extern fn nuc_dist_rank() -> i64;
extern fn nuc_dist_world_size() -> i64;
extern fn nuc_dist_barrier() -> i64;
extern fn nuc_dist_call_count() -> i64;
extern fn nuc_dist_reset() -> i64;

// =====================================================
// ReduceOp tags (stable IDs).
// =====================================================
fn reduce_op_sum()  -> i64 { return 1; }
fn reduce_op_prod() -> i64 { return 2; }
fn reduce_op_min()  -> i64 { return 3; }
fn reduce_op_max()  -> i64 { return 4; }
fn reduce_op_mean() -> i64 { return 5; }
fn reduce_op_band() -> i64 { return 6; }   // bitwise AND
fn reduce_op_bor()  -> i64 { return 7; }   // bitwise OR
fn reduce_op_bxor() -> i64 { return 8; }   // bitwise XOR

fn reduce_op_name(id: i64) -> str {
    if id == 1 { return "sum"; };
    if id == 2 { return "prod"; };
    if id == 3 { return "min"; };
    if id == 4 { return "max"; };
    if id == 5 { return "mean"; };
    if id == 6 { return "band"; };
    if id == 7 { return "bor"; };
    if id == 8 { return "bxor"; };
    return "unknown";
}

// =====================================================
// ShardSpec — encoded as a packed i64.
// High byte = kind tag (1=Replicate, 2=Shard, 3=Pipeline,
//                       4=ExpertParallel)
// Low bytes = parameter (axis / stage / num_experts).
// =====================================================
fn shard_spec_kind_replicate()      -> i64 { return 1; }
fn shard_spec_kind_shard()          -> i64 { return 2; }
fn shard_spec_kind_pipeline()       -> i64 { return 3; }
fn shard_spec_kind_expert_parallel() -> i64 { return 4; }

fn shard_spec_replicate() -> i64 {
    return shard_spec_kind_replicate() * 65536;
}
fn shard_spec_shard(axis: i64) -> i64 {
    return shard_spec_kind_shard() * 65536 + axis;
}
fn shard_spec_pipeline(stage: i64) -> i64 {
    return shard_spec_kind_pipeline() * 65536 + stage;
}
fn shard_spec_expert_parallel(num_experts: i64) -> i64 {
    return shard_spec_kind_expert_parallel() * 65536 + num_experts;
}

fn shard_spec_kind(s: i64) -> i64 { return s / 65536; }
fn shard_spec_param(s: i64) -> i64 { return s - (shard_spec_kind(s) * 65536); }

fn shard_spec_kind_name(kind: i64) -> str {
    if kind == 1 { return "Replicate"; };
    if kind == 2 { return "Shard"; };
    if kind == 3 { return "Pipeline"; };
    if kind == 4 { return "ExpertParallel"; };
    return "Unknown";
}

// =====================================================
// Process-group init / topology query.
// =====================================================
fn distributed_init(rank: i64, world_size: i64) -> i64 {
    return nuc_dist_init(rank, world_size);
}

fn distributed_rank() -> i64 { return nuc_dist_rank(); }
fn distributed_world_size() -> i64 { return nuc_dist_world_size(); }
fn distributed_barrier() -> i64 { return nuc_dist_barrier(); }
fn distributed_call_count() -> i64 { return nuc_dist_call_count(); }
fn distributed_reset() -> i64 { return nuc_dist_reset(); }

// =====================================================
// Collectives (Phase A: single-rank pass-through).
//
// Every fn here is the identity on world_size=1 and the call
// count is incremented in the runtime so test harnesses can
// confirm the rod surface is being exercised. Phase B routes
// to NCCL / RCCL / MPI / RDMA per backend.
// =====================================================
fn all_reduce(handle: i64, op: i64) -> i64 {
    nuc_dist_barrier();
    return handle;
}

fn all_gather(handle: i64) -> i64 {
    nuc_dist_barrier();
    return handle;
}

fn reduce_scatter(handle: i64, op: i64) -> i64 {
    nuc_dist_barrier();
    return handle;
}

fn broadcast(handle: i64, root: i64) -> i64 {
    nuc_dist_barrier();
    return handle;
}

fn all_to_all(handle: i64) -> i64 {
    nuc_dist_barrier();
    return handle;
}

// =====================================================
// Sharding helpers (Phase A: identity wrappers that record
// the shard spec on the returned struct).
// =====================================================
struct ShardedHandle {
    handle: i64,
    spec: i64,
}

fn tensor_parallel(handle: i64, axis: i64) -> ShardedHandle {
    return ShardedHandle { handle: handle, spec: shard_spec_shard(axis) };
}

fn pipeline_parallel(handle: i64, stage: i64) -> ShardedHandle {
    return ShardedHandle { handle: handle, spec: shard_spec_pipeline(stage) };
}

fn expert_parallel(handle: i64, num_experts: i64) -> ShardedHandle {
    return ShardedHandle { handle: handle, spec: shard_spec_expert_parallel(num_experts) };
}

fn replicate(handle: i64) -> ShardedHandle {
    return ShardedHandle { handle: handle, spec: shard_spec_replicate() };
}

fn sharded_handle_inner(s: ShardedHandle) -> i64 { return s.handle; }
fn sharded_handle_spec(s: ShardedHandle) -> i64 { return s.spec; }

// =====================================================
// RDMA scaffolding (Phase A: stub handles, real RDMA in
// Phase B).
// =====================================================
fn rdma_send(handle: i64, peer_rank: i64) -> i64 {
    nuc_dist_barrier();
    return handle;
}

fn rdma_recv(handle: i64, peer_rank: i64) -> i64 {
    nuc_dist_barrier();
    return handle;
}
