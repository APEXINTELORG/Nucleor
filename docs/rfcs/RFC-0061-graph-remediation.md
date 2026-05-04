# RFC-0061 — Graph Capability Remediation

**Status:** Draft (V1.17 / V1.18 / V1.19 — multi-tier)
**Date:** 2026-05-03
**Source:** `Desktop/Nucleor_Graph_Remediation_Spec_2026-05-03.md` (v0.1)
**Scope:** Closes the gap between Nucleor's stated "graph-capable / graph where possible / necessary" ambition and what currently ships in OSS.

## Summary

Five tiers, three of which are easy wins; one is a real architectural decision (graph-aware optimization passes restored from V2). Tier 4 is the optimization-pass decision.

## Tier breakdown

### Tier 1 — Cheap polish (V1.17a — do all of these)
- Add missing wrapper fns: `gnn_circuit_to_graph`, `astar_free`, `graph_has_negative_cycle`, `graph_negative_cycle_path`
- Add adjacency-matrix view to `graph.nr`: `graph_to_adjacency_matrix`, `graph_from_adjacency_matrix`, `graph_adjacency_density`
- Document `nuc graph` and `nuc impact` CLI verbs in `docs/language-reference.md §10`
- Add 3 smoke fixtures (`gnn_circuit_to_graph_smoke.nr`, `graph_negative_cycle_smoke.nr`, `graph_adjacency_matrix_smoke.nr`)

Cost: SMALL. ~150 LOC stdlib + ~50 LOC docs + 3 fixtures.

### Tier 2 — `nuc deps graph` CLI visualization (V1.17b)
New CLI verb:
```
nuc deps graph [--format=text|json|dot|mermaid] [--depth=N] [--include-stdlib]
```
Reuses existing `lock_build_graph_recursive`. Mirrors `cargo tree` / `go mod graph` / `npm ls`. ~150-200 LOC for format renderers.

Cost: SMALL.

### Tier 3 — Trace/event graph hardening (V1.18)
Expose quantum entanglement tracker and gate-influence DAG as queryable graphs:
```nucleor
fn qsim_entanglement_components(sim: i64) -> Vec<Vec<i64>>;
fn qsim_entanglement_count(sim: i64) -> i64;
fn qsim_entanglement_size(sim: i64, qubit: i64) -> i64;
fn qsim_gate_influence_dag(sim: i64) -> Graph;
```
First three: ~20-30 LOC C wrapper around existing union-find. Fourth: ~100-150 LOC for DAG assembly from trace events.

Cost: SMALL-MEDIUM.

### Tier 4 — Graph-aware optimization passes (V1.19 — DECISION REQUIRED)

**Gap:** V2/Copy claimed `attention()` → `flash_attention` IR rewrites + call-graph-driven leaf inlining + execution policy classification. OSS has the analysis (call graph, effect propagation, `nuc graph`/`nuc impact`) but the optimizer doesn't consume it.

**Two preflight questions:**

Q1 — Was V2 graph-aware optimization actually shipped or aspirational? **Confirm-pass against V2 source needed before any restoration.**

Q2 — If V2 had it shipped, was the OSS drop intentional? Possible reasons it was intentional: dependencies on `KvCache`/`KvPrefix` first-class IR types, `requires [...]`/`restricts [...]` keywords (pulled in v0.3.139/140), V2's typed `chan<T>`/`Mutex<T>`/`Atomic<T>` wrappers.

**Three options ordered by cost:**

- **Option A — Defer (do nothing now).** Document the gap; revisit if a major user asks for ML perf parity with PyTorch's graph compiler. Cost: zero.
- **Option B — Selective restore (recommended if V2 had it shipped):** restore the 2 highest-value rewrites — `attention(q,k,v) → flash_attention(q,k,v)` IR rewrite + call-graph-driven leaf inlining (single-param-use, IR cost ≤32 nodes). Skip the more ambitious pieces. Cost: MEDIUM.
- **Option C — Full restore.** Lift V2's typed wrapper system + restore `requires`/`restricts` keywords + full pipeline. Cost: LARGE.

**Recommended decision path:** run a Sonnet confirm-pass against `Nucleor_V2` source first. If "shipped + tested" → Option B as default. If "staged but unshipped" → Option A.

**Tier 4 does NOT block Tiers 1-3** (those are independent and net-positive regardless).

### Tier 5 — Documentation consolidation (V1.17c)
Create `docs/graph-capabilities.md` consolidating the graph story across rods, CLI, IR analysis, and trace events.

Cost: SMALL.

## Cross-references

- Source spec: `Desktop/Nucleor_Graph_Remediation_Spec_2026-05-03.md`
- Sister RFCs: existing `gnn.nr`, `graph.nr`, `astar.nr` rod docs
- Companion governance RFC: `RFC-0060-governance-rod.md`

## Acceptance criteria (Tier 1-3 + 5)

- All missing wrapper fns present and tested
- `nuc deps graph` produces 4 output formats correctly on the package dependency graph
- `qsim_entanglement_*` queries work end-to-end on a 4-qubit Bell-state simulator
- `docs/graph-capabilities.md` exists and is linked from main docs index
- Round-2 self-host fixed-point holds across all changes

## Acceptance criteria (Tier 4 — Option B if approved)

- `attention(q, k, v)` rewrites to `flash_attention(q, k, v)` at IR stage when shape conditions match
- Leaf-fn inlining fires on pure single-param-use fns with IR cost ≤32 nodes
- `nuc perf` emits a diagnostic when an `attention` call is NOT rewritten (with reason)
- ML benchmark suite shows measurable speedup (target: ≥1.3× on attention-heavy workloads)
