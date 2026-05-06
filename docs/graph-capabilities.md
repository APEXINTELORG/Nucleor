# Graph Capabilities

**Status:** Consolidated reference, V1.17c (RFC-0061 Tier 5 close-out, v0.8.4)

This document is the single landing page for everything graph-shaped in
Nucleor: which graph data types ship in stdlib, which CLI verbs query
the build/dependency/effect graphs, what's in the IR analysis layer, and
what the trace stream emits. It exists because the graph story is
genuinely cross-cutting — adopters porting Rust code, ML researchers
wiring GNN pipelines, and toolchain implementers reading the lockfile
all want different views of the same underlying topology.

For a quick overview, the four sections below cover **rods**, **CLI**,
**IR analysis**, and **trace events**. Each section names the
authoritative source files plus the canonical fixture or smoke test.

---

## 1. Stdlib rod surface

### `stdlib/rods/graph.nr` — Classical graph algorithms

Adjacency-list directed weighted graph with the canonical algorithm
suite. Backed by `stdlib/runtime/graph_rt.c`.

Construction + query:
- `graph_new(n_nodes) -> i64`
- `graph_add_edge(g, u, v, w_bits)` (weight as f64-bits)
- `graph_add_edge_undirected(g, u, v, w_bits)`
- `graph_free(g)`

Traversal:
- `graph_bfs(g, start) -> i64`, `graph_dfs(g, start) -> i64`

Shortest paths:
- `graph_dijkstra(g, src) -> i64`
- `graph_bellman_ford(g, src) -> i64`

Topology:
- `graph_topo_sort(g) -> i64`
- `graph_connected_components(g) -> i64`
- `graph_mst_kruskal(g) -> i64`
- `graph_pagerank(g, damping_bits, iters) -> i64`

**RFC-0061 Tier 1 V1.17a** (CLOSED v0.7.86) added:
- `graph_has_negative_cycle(g, src) -> i64` (v0.7.80) — Bellman-Ford
  witness pass
- `graph_negative_cycle_path(g, src) -> Vec<i64>` (v0.7.80) — walks
  predecessor chain
- `graph_to_adjacency_matrix(g) -> Vec<i64>` (v0.7.81) — flat n×n,
  no-edge sentinel = f64-bits(1e30)
- `graph_from_adjacency_matrix(matrix, n_nodes) -> i64` (v0.7.81)
- `graph_adjacency_density(g) -> i64` (v0.7.81) — f64-bits in [0,1]

### `stdlib/rods/graph_render.nr` — Format renderers

**RFC-0061 Tier 2 Phase A** (v0.7.94) added the canonical
text/JSON/DOT/Mermaid format-renderer surface. Adopters can render any
graph rod handle to a printable string; the future
`nuc deps graph --format=...` CLI verb will wrap these helpers.

Per-format renderers: `graph_render_text`, `graph_render_json`,
`graph_render_dot`, `graph_render_mermaid` — each takes
`(g, names: Vec<str>)` and returns a `str`. Pass
`graph_render_anon_names()` if you don't have node labels.

Format dispatch by tag: `graph_render_with_format(g, names, format_id)`
+ `graph_render_format_{text, json, dot, mermaid}` ID constants +
`_format_id(name) -> i64` round-trip.

### `stdlib/rods/qsim_graph.nr` — Quantum entanglement + gate DAG

**RFC-0061 Tier 3 Phase A** (v0.8.3) added an entanglement union-find
+ gate-influence DAG independent of the quantum rod's tracing path.

Entanglement (union-find over qubits, max 1024):
- `qsim_entangle_register(q1, q2)` — unions
- `qsim_entanglement_root / _same / _size / _count / _clear`

Gate-influence DAG (max 4096 gates):
- `qsim_gate_record(name, q1, q2)` — q2 = -1 for 1-qubit
- `qsim_gate_record_preflight(q1, q2)` — status
  `0=ok`, `1=out_of_range`, `2=dag_full`
- `qsim_gate_record_checked(name, q1, q2)` — returns real gate id
  on success, or negative status (`-1`, `-2`, `-3`) on failure
- `qsim_gate_dag_size / _depends_on (transitive BFS) / _parent_count /
  _parent_at / _clear`

Combined: `qsim_graph_clear()`.

### `stdlib/rods/gnn.nr` — Graph Neural Networks

GATv2Conv + GlobalAttention pooling + circuit-to-graph bridge,
backed by `stdlib/runtime/gnn_rt.c`.

Canonical wrapper-fn surface added in v0.7.78 (RFC-0061 Tier 1):
- `gnn_circuit_to_graph(gates, nq) -> i64` (the spec's missing
  wrapper)
- `gnn_graph_new / _free / _n_nodes`
- `gnn_gatv2_new / _forward / _backward / _adam_step / _zero_grad /
  _param_count`
- `gnn_global_attn_new / _forward / global_mean_pool`
- `gnn_layer_norm / _relu`

### `stdlib/rods/astar.nr` — A* with custom heuristic

Wraps `astar_rt.c`. `astar_search(start, goal, heuristic_fn)` with the
goal/visited/predecessor tables managed in C. `astar_free(handle)`
cleans up.

### `stdlib/rods/vgraph.nr` — Visualization graphs

Wraps `vgraph_rt.c`. Used by the v0.7.78 GNN smoke fixture and by
`nuc graph` JSON output.

---

## 2. CLI verbs

Documented in `docs/language-reference.md §10`. The triple
`nuc deps` (lock graph) + `nuc graph` (source forward) +
`nuc impact` (reverse) compose as three views of the same project.

### `nuc graph [file]` — Source-level call/effect graph

Forward call graph. One per-fn block: `calls:` (forward edges),
`effects:` (io / panic / alloc / ... transitively closed). Pass
`--json` for machine-readable output that pipes into the
`stdlib/rods/graph.nr` surface for further analysis. (See language-
reference.md §10.1.)

### `nuc impact <file> <fn>` — Reverse call graph

Walks the caller relation from `<fn>` to fixpoint. Use case: changing
a fn's signature and wanting to know the blast radius. Empty list =
unreachable from anything else, safe to delete. (See language-
reference.md §10.2.)

### `nuc deps` — Lock-file dependency graph

Reads the project's `Nucleor.lock` and walks the `import` chain.
Supports `--depth=N` and `--include-stdlib`. The future
`nuc deps graph --format=text|json|dot|mermaid` verb (RFC-0061 Tier 2
Phase B) wraps the format-renderer surface added in v0.7.94.

---

## 3. IR analysis layer

`compiler/nucleor_s1_compiler.nr` runs a per-build call-graph analysis
that downstream consumers (effect propagation, capability inference,
DCE) all read from:

- **Call graph** — `lower_program` builds the ident → caller-set map at
  parse-resolution time.
- **Effect propagation** — fns inherit `io` / `panic` / `alloc` / etc.
  effects from their transitive callees (sister to the existing
  `#[no_alloc]` / `#[no_panic]` substrate; v1.6 ship promotes to
  type-checked enforcement).
- **Lock-build graph** — `lock_build_graph_recursive` constructs the
  module-import DAG at lockfile-emit time.

These are queryable via `nuc graph` / `nuc impact` / `nuc deps` (see
section 2).

The IR layer also produces the call-graph data that the trace stream
in section 4 references.

---

## 4. Trace stream + entanglement events

`stdlib/rods/quantum.nr` emits trace events through
`rods_trace_entangle(gate, q1, q2)` on every CNOT / CZ / CRK / CCX.
The same high-level qsim wrappers now also update the queryable
`qsim_graph` process-local graph:

1. CNOT / CZ / CRK call `qsim_entangle_register(ctrl, tgt)` and then
   `qsim_gate_record_checked(name, ctrl, tgt)`.
2. CCX calls `qsim_entangle_register(c1, tgt)` and
   `qsim_entangle_register(c2, tgt)`, then records those two
   control-target DAG relationships. This is an edge representation,
   not a single three-qubit DAG node, because the public checked-record
   API is two-qubit.
3. SWAP inherits both entanglement and DAG records through its existing
   three-CNOT decomposition.
4. External `nuc audit` / governance pipelines (RFC-0060) can still use
   the trace stream as audit provenance.

The raw gate-influence DAG (`qsim_gate_record`) records explicit
(gate, q1, q2) tuples; parent linking via the last-gate-on-qubit table
gives transitive `depends_on` queries in O(N_gates) BFS time. Prefer
`qsim_gate_record_checked` for adopter code so out-of-range and
DAG-full failures are visible at the Nucleor layer.

Current limits: `qsim_graph` state is process-local and is not
thread-safe across pthread/async boundaries. Call `qsim_graph_clear()`
between independent circuits.

---

## 5. Cross-references

- `RFC-0061 Graph Remediation` — `docs/rfcs/RFC-0061-graph-remediation.md`
- Source spec — `Desktop/Nucleor_Graph_Remediation_Spec_2026-05-03.md`
- Companion governance — `RFC-0060 Governance Rod`
  (`docs/rfcs/RFC-0060-governance-rod.md`)
- Section 2 verbs — `docs/language-reference.md §10.1, §10.2`
- Smoke fixtures —
  `tests/fixtures/v0780_rfc0061_negative_cycle_smoke.nr`,
  `tests/fixtures/v0781_rfc0061_adjacency_matrix_smoke.nr`,
  `tests/fixtures/v0794_rfc0061_graph_render_smoke.nr`,
  `tests/fixtures/v0803_rfc0061_tier3_qsim_graph_smoke.nr`,
  `tests/features/qsim_graph_auto_entangle_smoke.nr`,
  `tests/features/qsim_graph_auto_record_smoke.nr`.

---

## 6. RFC-0061 status snapshot

| Tier | Title | Status |
|---|---|---|
| 1 (V1.17a) | Cheap polish: gnn wrappers, neg-cycle, adjacency matrix, CLI docs | **CLOSED** v0.7.86 |
| 2 (V1.17b) | `nuc deps graph` formatters | **Phase A** v0.7.94 (CLI verb deferred) |
| 3 (V1.18) | Trace/event graph hardening | **Phase A** v0.8.3 (full ship wires trace hook) |
| 4 (V1.19) | Graph-aware optimization passes | **PRE-DECISION** (V2 confirm-pass needed) |
| 5 (V1.17c) | Documentation consolidation | **CLOSED** v0.8.4 (this doc) |

Tier 4 has two preflight questions documented in the RFC: was V2
graph-aware-optimization actually shipped, and was the OSS drop
intentional? Three options ordered by cost: A — defer, B — restore
read-only analysis, C — full optimizer-consumer rewire. Do not start
without the V2 source audit answer.
