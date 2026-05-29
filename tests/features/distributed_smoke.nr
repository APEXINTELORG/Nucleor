// v0.8.203 stdlib/rods/distributed.nr first test coverage.
//
// RFC-0055 Phase A: collectives + sharding-spec surface
// (single-rank pass-through). Pre-v0.8.203: zero coverage on
// the standalone rod.
//
// Locks four lifecycle/encoding invariants that real Phase B
// dispatch must NOT regress:
//
//   1. Init + topology query: distributed_init(0, 1) →
//      rank == 0, world_size == 1.
//   2. Collectives are identity on world=1: all_reduce
//      and broadcast return the input handle unchanged.
//   3. call_count tracks barrier ops: every collective
//      bumps the counter (verifies the rod surface routes
//      through the runtime).
//   4. ShardSpec encoding round-trip: shard_spec_shard(2)
//      → kind == 2, param == 2 (axis preserved).
//
// Expected: rc=0.

import "stdlib/rods/distributed.nr"

fn check_init_topology() -> i64 {
    distributed_init(0, 1);
    if distributed_rank() != 0 { return 1; };
    if distributed_world_size() != 1 { return 2; };
    return 0;
}

fn check_all_reduce_identity() -> i64 {
    distributed_init(0, 1);
    let h: i64 = 42;
    let out: i64 = all_reduce(h, reduce_op_sum());
    if out != 42 { return 4; };
    let bcast: i64 = broadcast(h, 0);
    if bcast != 42 { return 8; };
    return 0;
}

fn check_call_count() -> i64 {
    distributed_init(0, 1);
    distributed_reset();
    let before: i64 = distributed_call_count();
    all_reduce(7, reduce_op_sum());
    all_reduce(8, reduce_op_sum());
    broadcast(9, 0);
    let after: i64 = distributed_call_count();
    if (after - before) != 3 { return 16; };
    return 0;
}

fn check_shard_spec_round_trip() -> i64 {
    let s: i64 = shard_spec_shard(2);
    if shard_spec_kind(s) != shard_spec_kind_shard() { return 32; };
    if shard_spec_param(s) != 2 { return 64; };
    let p: i64 = shard_spec_pipeline(3);
    if shard_spec_kind(p) != shard_spec_kind_pipeline() { return 128; };
    if shard_spec_param(p) != 3 { return 256; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_init_topology();
    fails = fails + check_all_reduce_identity();
    fails = fails + check_call_count();
    fails = fails + check_shard_spec_round_trip();
    return fails;
}
