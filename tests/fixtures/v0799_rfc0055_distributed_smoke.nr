// v0.7.99 RFC-0055 Phase A smoke fixture — distributed
// collectives + sharding-spec surface. Validates:
//   - ReduceOp tags + name lookup
//   - ShardSpec encoding round-trip (kind / param)
//   - Process-group init + rank / world_size queries
//   - All collectives are pass-through identity on
//     world_size=1 and increment the call counter
//   - Sharded handle constructors capture the spec
import "stdlib/rods/distributed.nr"

fn main() -> i64 {
    distributed_reset();

    // ReduceOp tags.
    if reduce_op_sum() != 1 { return 1; };
    if reduce_op_prod() != 2 { return 2; };
    if reduce_op_mean() != 5 { return 3; };
    if str_eq(reduce_op_name(reduce_op_sum()), "sum") == 0 { return 4; };
    if str_eq(reduce_op_name(reduce_op_max()), "max") == 0 { return 5; };
    if str_eq(reduce_op_name(99), "unknown") == 0 { return 6; };

    // ShardSpec encoding round-trip.
    let s_rep: i64 = shard_spec_replicate();
    if shard_spec_kind(s_rep) != shard_spec_kind_replicate() { return 7; };

    let s_shard: i64 = shard_spec_shard(2);
    if shard_spec_kind(s_shard) != shard_spec_kind_shard() { return 8; };
    if shard_spec_param(s_shard) != 2 { return 9; };

    let s_pipe: i64 = shard_spec_pipeline(3);
    if shard_spec_kind(s_pipe) != shard_spec_kind_pipeline() { return 10; };
    if shard_spec_param(s_pipe) != 3 { return 11; };

    let s_expert: i64 = shard_spec_expert_parallel(8);
    if shard_spec_kind(s_expert) != shard_spec_kind_expert_parallel() { return 12; };
    if shard_spec_param(s_expert) != 8 { return 13; };

    if str_eq(shard_spec_kind_name(2), "Shard") == 0 { return 14; };
    if str_eq(shard_spec_kind_name(99), "Unknown") == 0 { return 15; };

    // Process-group init.
    distributed_init(0, 1);
    if distributed_rank() != 0 { return 16; };
    if distributed_world_size() != 1 { return 17; };
    if distributed_call_count() != 0 { return 18; };

    // Collectives: identity + increment call counter.
    let h: i64 = 42;
    if all_reduce(h, reduce_op_sum()) != 42 { return 19; };
    if all_gather(h) != 42 { return 20; };
    if reduce_scatter(h, reduce_op_max()) != 42 { return 21; };
    if broadcast(h, 0) != 42 { return 22; };
    if all_to_all(h) != 42 { return 23; };
    if rdma_send(h, 1) != 42 { return 24; };
    if rdma_recv(h, 1) != 42 { return 25; };

    if distributed_call_count() != 7 { return 26; };

    // Sharded handle constructors.
    let tp: ShardedHandle = tensor_parallel(99, 1);
    if sharded_handle_inner(tp) != 99 { return 27; };
    if shard_spec_kind(sharded_handle_spec(tp)) != shard_spec_kind_shard() { return 28; };
    if shard_spec_param(sharded_handle_spec(tp)) != 1 { return 29; };

    let pp: ShardedHandle = pipeline_parallel(11, 4);
    if shard_spec_kind(sharded_handle_spec(pp)) != shard_spec_kind_pipeline() { return 30; };
    if shard_spec_param(sharded_handle_spec(pp)) != 4 { return 31; };

    let ep: ShardedHandle = expert_parallel(7, 16);
    if shard_spec_kind(sharded_handle_spec(ep)) != shard_spec_kind_expert_parallel() { return 32; };
    if shard_spec_param(sharded_handle_spec(ep)) != 16 { return 33; };

    let rp: ShardedHandle = replicate(5);
    if shard_spec_kind(sharded_handle_spec(rp)) != shard_spec_kind_replicate() { return 34; };

    // World-size != 1 sanity.
    distributed_init(2, 8);
    if distributed_rank() != 2 { return 35; };
    if distributed_world_size() != 8 { return 36; };

    distributed_reset();
    if distributed_call_count() != 0 { return 37; };

    return 0;
}
