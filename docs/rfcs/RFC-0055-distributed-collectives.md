# RFC-0055 — `std.distributed` Collectives + Topology-Aware Sharding

**Status:** Draft (frontier — V2.10, mostly rod-level)
**Date:** 2026-05-03

## Motivation

Modern foundation-model training and inference is distributed across hundreds-to-thousands of accelerators. Nucleor has `comm.nr` (depth uncertain — needs audit) but doesn't yet match JAX/PyTorch's distributed primitives:
- **Collectives:** all_reduce, all_gather, reduce_scatter, broadcast
- **Sharding patterns:** pipeline_parallel, tensor_parallel, expert_parallel
- **Topology-awareness:** rdma_send/recv, fault-domain replication, NIC-aware ring choice
- **Checkpointing:** checkpoint, restart, deterministic recovery from mid-step failure

## Design

Mostly rod-level (`std.distributed`) with one language-level type for sharded tensors.

### Language-level surface

```nucleor
struct ShardedTensor<T, Shape, ShardSpec> {
    shards: Vec<Tensor<T, Shape>>,    // local shards on this rank
    rank: u32,
    world_size: u32,
}

enum ShardSpec {
    Replicate,
    Shard(axis: u8),
    Pipeline(stage: u8),
    ExpertParallel(num_experts: u16),
}
```

Phantom-typed `ShardSpec` so the type-checker can enforce that you don't accidentally apply tensor-parallel matmul to a pipeline-sharded tensor.

### Rod surface (`std.distributed`)

```nucleor
fn all_reduce<T>(t: Tensor<T>, op: ReduceOp) -> Tensor<T>
fn all_gather<T>(t: Tensor<T>) -> Tensor<T>
fn reduce_scatter<T>(t: Tensor<T>, op: ReduceOp) -> Tensor<T>
fn broadcast<T>(t: Tensor<T>, root: u32) -> Tensor<T>

fn pipeline_parallel<T>(stages: Vec<fn(Tensor<T>) -> Tensor<T>>, input: Tensor<T>) -> Tensor<T>
fn tensor_parallel<T>(shard: Tensor<T>, axis: u8) -> ShardedTensor<T, _, Shard(axis)>
fn expert_parallel<T>(experts: Vec<fn(Tensor<T>) -> Tensor<T>>, gates: Tensor<T>) -> Tensor<T>

fn rdma_send<T>(t: Tensor<T>, peer: u32) -> RdmaHandle
fn rdma_recv<T>(handle: RdmaHandle) -> Tensor<T>

fn topology_aware_shard<T>(t: Tensor<T>, topology: Topology) -> ShardedTensor<T, _, _>

fn checkpoint(state: TrainState, path: str) -> Result<(), IoError>
fn restart(path: str) -> Result<TrainState, IoError>
```

### Backend dispatch

Three transports:
- **CPU MPI / Gloo** — local development, validation
- **NCCL / NVLink** — NVIDIA GPU clusters
- **RCCL / xGMI** — AMD GPU clusters

Compile-time selection via `target.has(NCCL)` / `target.has(MPI)` (RFC-0048 capability queries). Runtime fallback to MPI when no accelerator transport available.

## Implementation

V2.10 ship covers:
- Language: `ShardedTensor` type + `ShardSpec` enum + topology query (`std.distributed::topology()` via runtime detection or env var like `NUCLEOR_DIST_RANKS`).
- Rod: collectives via MPI fallback (links against MS-MPI on Windows, OpenMPI on Linux). NCCL/RCCL backend deferred to follow-on ship.
- CLI: `nuc run --np=N` launches N ranks via MPI launcher.

## Cost

V2.10: ~400 LOC compiler (ShardedTensor type + topology query) + ~3000 LOC stdlib `std.distributed` rod (8 collectives + 3 parallel patterns + RDMA + checkpoint/restart) + MPI link wiring. ~1 week of focused work.

NCCL/RCCL backend: separate v2.x ship per vendor.

## Hot-path risk

None. Distributed code path is a separate compilation unit; existing single-rank hot path untouched.

## Frontier connection

Direct frontier writeup §3.2.6. Pairs with **RFC-0049 memory-space type tags** (sharded tensors live in HBM by default; pipeline stages may straddle HBM + DDR).

## Closure criteria

- 8 collectives work end-to-end on MPI fallback.
- `tensor_parallel` produces correct attention output when run on 4 ranks.
- Checkpoint/restart round-trips a 7B-param model state.
- `nuc run --np=4` launches 4 MPI ranks.
- Round-2 self-host fixed-point holds.
