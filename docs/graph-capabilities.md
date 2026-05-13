# Graph Capabilities

Nucleor has graph support in three places: standard-library rods, CLI analysis
verbs, and quantum/ML helper surfaces.

## Stdlib Rods

### `stdlib/rods/graph.nr`

Directed weighted graph backed by `stdlib/runtime/graph_rt.c`.

Construction and query:

- `graph_new(n_nodes) -> i64`
- `graph_add_edge(g, u, v, w_bits)`
- `graph_add_edge_undirected(g, u, v, w_bits)`
- `graph_free(g)`

Traversal and analysis:

- `graph_bfs(g, start) -> i64`
- `graph_dfs(g, start) -> i64`
- `graph_dijkstra(g, src) -> i64`
- `graph_bellman_ford(g, src) -> i64`
- `graph_has_negative_cycle(g, src) -> i64`
- `graph_negative_cycle_path(g, src) -> Vec<i64>`
- `graph_topo_sort(g) -> i64`
- `graph_connected_components(g) -> i64`
- `graph_mst_kruskal(g) -> i64`
- `graph_pagerank(g, damping_bits, iters) -> i64`
- `graph_to_adjacency_matrix(g) -> Vec<i64>`
- `graph_from_adjacency_matrix(matrix, n_nodes) -> i64`
- `graph_adjacency_density(g) -> i64`

### `stdlib/rods/graph_render.nr`

Renders graph handles as text, JSON, DOT, or Mermaid:

- `graph_render_text`
- `graph_render_json`
- `graph_render_dot`
- `graph_render_mermaid`
- `graph_render_with_format`
- `graph_render_format_id`

### `stdlib/rods/qsim_graph.nr`

Tracks quantum entanglement relationships and gate-influence DAGs:

- `qsim_entangle_register`
- `qsim_entanglement_root`
- `qsim_entanglement_same`
- `qsim_entanglement_size`
- `qsim_entanglement_count`
- `qsim_gate_record`
- `qsim_gate_record_checked`
- `qsim_gate_depends_on`
- `qsim_graph_clear`

### `stdlib/rods/gnn.nr`

Graph neural-network helpers backed by `stdlib/runtime/gnn_rt.c`:

- `gnn_circuit_to_graph`
- `gnn_graph_new`
- `gnn_gatv2_new`
- `gnn_gatv2_forward`
- `gnn_global_attn_new`
- `global_mean_pool`
- `gnn_layer_norm`

### Other Rods

- `stdlib/rods/astar.nr` exposes A* search with a custom heuristic.
- `stdlib/rods/vgraph.nr` exposes visualization graph handles used by graph
  tooling.

## CLI Verbs

### `nuc graph [file]`

Prints a source-level forward call/effect graph. Use `--json` when another tool
needs to consume the output.

### `nuc impact <file> <fn>`

Prints every function that transitively depends on `<fn>`. This is useful before
changing a function signature or deleting unused code.

### `nuc deps`

Reads the project's lockfile and walks the import graph. Supports depth control
and optional stdlib inclusion.

## Compiler Layer

The compiler builds internal call graphs for effect propagation, capability
checking, dead-code elimination, and project graph reporting. These are exposed
through the CLI verbs above rather than a separate public IR API.

## Current Limits

- `qsim_graph` state is process-local.
- Some graph renderers use flat string output rather than streaming writers.
- The dependency graph tools are intended for inspection, not as a package
  resolver API.
